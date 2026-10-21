import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/automatic_artwork_resolver.dart';

/// One debounced selection at a time. Artwork never delays installing audio.
class AutomaticArtworkStore extends ChangeNotifier {
  AutomaticArtworkStore({
    required this.directory,
    required this.cache,
    required this.validate,
    required this.canFetch,
    this.retainedPaths,
    this.report,
    AutomaticArtworkResolver Function()? resolverFactory,
    this.debounce = const Duration(milliseconds: 700),
    this.minimumLookupInterval = const Duration(seconds: 6),
    DateTime Function()? now,
  }) : resolverFactory = resolverFactory ?? AutomaticArtworkResolver.new,
       now = now ?? DateTime.now;
  final Directory directory;
  final Box cache;
  final Future<bool> Function(String) validate;
  final Future<bool> Function() canFetch;
  final Future<Set<String>> Function()? retainedPaths;
  final void Function(String)? report;
  final AutomaticArtworkResolver Function() resolverFactory;
  final Duration debounce;
  final Duration minimumLookupInterval;
  DateTime? _lastLookup;
  String? _activeId;
  final DateTime Function() now;
  final _byId = <String, String>{};
  Timer? _timer;
  AutomaticArtworkResolver? _resolver;
  String? _selection;
  int _epoch = 0;
  bool _disposed = false;
  DateTime? _pausedUntil;
  final _retryAfter = <String, DateTime>{};
  Future<void> _work = Future.value();
  Future<void> get pending => _work;
  static const _prefix = 'automatic-artwork:';
  static const maxCacheBytes = 80 * 1024 * 1024;
  static const maxCacheFiles = 20;

  static String identity(MediaItem item) => sha256
      .convert(
        utf8.encode(
          '${artworkTitle(item.title)}\n${artworkName(item.artist ?? '')}\n${artworkName(item.album ?? '')}',
        ),
      )
      .toString();

  String? fileFor(String id) {
    final file = _byId[id];
    if (file == null) return null;
    final path = '${directory.path}/$file';
    return File(path).existsSync() ? path : null;
  }

  void select(MediaItem? item, {required bool enabled}) {
    final eligible =
        enabled &&
        item != null &&
        item.isLive != true &&
        (item.artist ?? '').trim().isNotEmpty;
    final id = item?.extras?['ytid']?.toString() ?? item?.id;
    final fingerprint = eligible ? identity(item) : null;
    final selection = fingerprint == null ? null : '$id:$fingerprint';
    if (_selection == selection) return;
    _selection = selection;
    _activeId = eligible ? id : null;
    final epoch = ++_epoch;
    _timer?.cancel();
    _resolver?.close();
    _resolver = null;
    if (!eligible || id == null || fingerprint == null || _disposed) return;
    _byId.remove(id);
    final stored = cache.get('$_prefix$fingerprint');
    if (stored is Map && stored['at'] is int) {
      final age = now().difference(
        DateTime.fromMillisecondsSinceEpoch(stored['at'] as int),
      );
      final filename = stored['file'];
      if (filename is String &&
          RegExp(r'^[a-f0-9]{64}\.mp4$').hasMatch(filename)) {
        final file = File('${directory.path}/$filename');
        if (file.existsSync() && file.lengthSync() == stored['bytes']) {
          final changed = _byId[id] != filename;
          _byId[id] = filename;
          unawaited(
            file.setLastModified(now()).then((_) {}, onError: (Object _) {}),
          );
          if (changed)
            scheduleMicrotask(() {
              if (!_disposed && _epoch == epoch) notifyListeners();
            });
          if (age < const Duration(days: 7)) return;
        }
      } else if (stored['missing'] == true && age < const Duration(days: 1)) {
        return;
      }
    }
    if ((_pausedUntil?.isAfter(now()) ?? false) ||
        (_retryAfter[fingerprint]?.isAfter(now()) ?? false))
      return;
    final remaining = _lastLookup == null
        ? Duration.zero
        : _lastLookup!.add(minimumLookupInterval).difference(now());
    _timer = Timer(remaining > debounce ? remaining : debounce, () {
      _timer = null;
      _work = _lookup(item, id, fingerprint, epoch);
    });
  }

  Future<void> _lookup(
    MediaItem item,
    String id,
    String fingerprint,
    int epoch,
  ) async {
    bool current() => !_disposed && _epoch == epoch;
    AutomaticArtworkResolver? resolver;
    File? temporary;
    try {
      if (!await canFetch() || !current()) {
        report?.call('suppressed by system or selection');
        return;
      }
      _lastLookup = now();
      resolver = resolverFactory();
      _resolver = resolver;
      final clip = await resolver.find(item, current: current);
      if (!current()) return;
      if (clip == null) {
        report?.call('no confident match with a supported clip');
        final hadArtwork = _byId.remove(id) != null;
        if (hadArtwork) notifyListeners();
        await cache.put('$_prefix$fingerprint', {
          'at': now().millisecondsSinceEpoch,
          'missing': true,
        });
        return;
      }
      await directory.create(recursive: true);
      final name = '${sha256.convert(utf8.encode(clip.movie.toString()))}.mp4';
      final file = File('${directory.path}/$name');
      if (!await file.exists()) {
        temporary = File('${file.path}.$epoch.partial');
        await resolver.download(clip.movie, temporary, current: current);
        if (!current()) return;
        if (!await validate(temporary.path))
          throw const FormatException('Unsupported artwork clip');
        if (!current()) return;
        await temporary.rename(file.path);
        temporary = null;
      }
      if (!current()) return;
      await cache.put('$_prefix$fingerprint', {
        'at': now().millisecondsSinceEpoch,
        'file': name,
        'bytes': await file.length(),
        'albumId': clip.albumId,
      });
      if (!current()) return;
      _byId[id] = name;
      report?.call('clip cached and ready');
      notifyListeners();
      await _trim(name);
    } on ArtworkLookupBusy {
      report?.call('provider requested backoff');
      if (current()) _pausedUntil = now().add(const Duration(minutes: 10));
    } on ArtworkLookupCancelled {
      // A newer selection or an opt-out superseded this work.
    } catch (error) {
      report?.call('lookup failed: ${error.runtimeType}');
      // Fail quietly to still artwork; transient failures are not cached as absence.
      if (current())
        _retryAfter[fingerprint] = now().add(const Duration(minutes: 2));
    } finally {
      resolver?.close();
      if (identical(_resolver, resolver)) _resolver = null;
      if (temporary != null && await temporary.exists())
        await temporary.delete();
    }
  }

  Future<void> prune() async => _trim(_byId[_activeId] ?? '');

  Future<void> _trim(String protected) async {
    if (!await directory.exists()) return;
    // iOS may still hold the previous selection while metadata catches up.
    final pinned = await retainedPaths?.call() ?? <String>{};
    final files = <({File file, FileStat stat})>[];
    await for (final entry in directory.list()) {
      if (entry is File &&
          (entry.path.endsWith('.mp4') || entry.path.endsWith('.partial')))
        files.add((file: entry, stat: await entry.stat()));
    }
    files.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    var bytes = files.fold<int>(0, (sum, item) => sum + item.stat.size);
    var count = files.length;
    for (final item in files) {
      if (count <= maxCacheFiles && bytes <= maxCacheBytes) break;
      if (pinned.contains(item.file.path) ||
          item.file.path.endsWith('/$protected') ||
          (_activeId != null &&
              item.file.path.endsWith('/${_byId[_activeId]}')))
        continue;
      await item.file.delete();
      bytes -= item.stat.size;
      count--;
    }
  }

  Future<void> clear({Future<void> Function()? beforeDelete}) async {
    ++_epoch;
    _timer?.cancel();
    _resolver?.close();
    await _work;
    _byId.clear();
    _retryAfter.clear();
    _pausedUntil = null;
    if (!_disposed) notifyListeners();
    // A published animated artwork URL must stay valid until iOS releases it.
    await beforeDelete?.call();
    if (await directory.exists()) await directory.delete(recursive: true);
    await cache.deleteAll(
      cache.keys
          .whereType<String>()
          .where((k) => k.startsWith(_prefix))
          .toList(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _timer?.cancel();
    _resolver?.close();
    super.dispose();
  }
}
