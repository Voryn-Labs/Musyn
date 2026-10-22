import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';

enum VocalPhase { off, preparing, ready, failed }

typedef VocalPrepare =
    Future<String> Function(MediaItem, int, void Function(String, double));

/// Coordinates real stem processing without pausing a working source or allowing
/// a late separation result to install onto another song.
class VocalReductionController extends ChangeNotifier {
  VocalReductionController({
    required this.prepare,
    required this.install,
    required this.mix,
    required this.cancel,
    this.available = true,
  });
  final bool available;
  final VocalPrepare prepare;
  final Future<bool> Function(String id, String path) install;
  final Future<void> Function(double level) mix;
  final Future<void> Function() cancel;
  String? _key;
  int _epoch = 0;
  VocalPhase phase = VocalPhase.off;
  double level = 1;
  double progress = 0;
  String status = 'Reduce vocals on this device';
  bool wanted = false;
  Future<void> pending = Future.value();
  Future<bool>? _installing;
  static String identity(MediaItem item) =>
      '${item.id}|${item.extras?['resolvedSource']}|${item.extras?['resolvedBitrate']}';
  void select(MediaItem? item) {
    if (!available) return;
    final key = item == null ? null : identity(item);
    if (key == _key) return;
    _key = key;
    ++_epoch;
    wanted = false;
    phase = VocalPhase.off;
    level = 1;
    progress = 0;
    status = 'Reduce vocals on this device';
    unawaited(cancel().catchError((Object _) {}));
    notifyListeners();
  }

  Future<void> enable(MediaItem item) {
    if (!available) {
      wanted = false;
      phase = VocalPhase.off;
      status = 'Sing Along is coming soon';
      notifyListeners();
      return Future.value();
    }
    select(item);
    wanted = true;
    if (phase == VocalPhase.ready) return setLevel(0);
    if (phase == VocalPhase.preparing) return pending;
    final epoch = ++_epoch;
    phase = VocalPhase.preparing;
    status = 'Preparing vocal reduction';
    progress = 0;
    notifyListeners();
    return pending = _run(item, epoch);
  }

  Future<void> _run(MediaItem item, int epoch) async {
    try {
      final path = await prepare(item, epoch, (stage, value) {
        if (epoch != _epoch || !wanted) return;
        status = stage;
        progress = value.clamp(0, 1);
        notifyListeners();
      });
      if (epoch != _epoch || !wanted || _key != identity(item)) return;
      final previousInstall = _installing;
      if (previousInstall != null) await previousInstall;
      if (epoch != _epoch || !wanted || _key != identity(item)) return;
      status = 'Applying separated audio';
      notifyListeners();
      final installation = install(item.id, path);
      _installing = installation;
      late final bool installed;
      try {
        installed = await installation;
      } finally {
        if (identical(_installing, installation)) _installing = null;
      }
      if (!installed)
        throw StateError(
          'The selection changed or the prepared audio could not be loaded',
        );
      if (epoch != _epoch || !wanted) return;
      await mix(0);
      if (epoch != _epoch || !wanted) {
        if (_key == identity(item) && !wanted) await mix(1);
        return;
      }
      phase = VocalPhase.ready;
      level = 0;
      status = 'Vocals reduced';
      progress = 1;
      notifyListeners();
    } catch (error) {
      if (epoch != _epoch) return;
      phase = VocalPhase.failed;
      wanted = false;
      status = error is PlatformException
          ? error.message ?? 'Vocal reduction unavailable'
          : 'Vocal reduction could not be prepared. Your original audio is retained.';
      logger.log('Vocal reduction failed', error: error.runtimeType);
      notifyListeners();
    }
  }

  Future<void> setLevel(double value) async {
    if (!available) return;
    if (!value.isFinite || phase != VocalPhase.ready) return;
    final epoch = _epoch;
    level = value.clamp(0, 1);
    wanted = level < 1;
    notifyListeners();
    try {
      await mix(level);
    } catch (_) {
      if (epoch == _epoch) {
        status = 'Vocal level could not be changed';
        notifyListeners();
      }
    }
  }

  Future<void> disable() async {
    if (!available) return;
    wanted = false;
    if (phase == VocalPhase.ready) {
      await setLevel(1);
      return;
    }
    final epoch = ++_epoch;
    try {
      await cancel();
    } catch (_) {}
    if (epoch != _epoch) return;
    phase = VocalPhase.off;
    progress = 0;
    status = 'Original audio';
    notifyListeners();
  }
}

class NativeVocalPreparation {
  NativeVocalPreparation() {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'progress' || call.arguments is! Map) return;
      final args = call.arguments as Map;
      if (args['request'] == _request &&
          args['stage'] is String &&
          args['progress'] is num) {
        _progress?.call(
          args['stage'] as String,
          (args['progress'] as num).toDouble(),
        );
      }
    });
  }
  static const channel = MethodChannel('com.vorynlabs.musyn/sing');

  // A signed stream URL changes on each resolution; its recording ID does not.
  // Unknown provider identities deliberately fall back to content hashing.
  static String? cacheIdentity(MediaItem item, Uri uri) {
    final extras = item.extras ?? const <String, dynamic>{};
    final provider = extras['resolvedSource'] ?? extras['downloadSource'];
    final recording = provider == 'jiosaavn'
        ? extras['saavnId']?.toString()
        : provider == 'youtube'
        ? extras['ytid']?.toString()
        : null;
    if (recording == null || recording.isEmpty || uri.scheme != 'https') {
      return null;
    }
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              'sing-cache-v1', provider, recording, extras['resolvedBitrate'],
              extras['resolvedFormat'],
              // YouTube's CDN identifies a specific encode with id/itag. JioSaavn
              // recording paths are stable even when query authentication rotates.
              if (provider == 'youtube')
                [uri.queryParameters['id'], uri.queryParameters['itag']]
              else
                uri.path,
            ]),
          ),
        )
        .toString();
  }

  http.Client? _client;
  int? _request;
  void Function(String, double)? _progress;
  Future<void> cancel() async {
    _request = null;
    _client?.close();
    _client = null;
    _progress = null;
    try {
      await channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  Future<String> prepare(
    MediaItem item,
    int request,
    void Function(String, double) progress,
  ) async {
    if (!Platform.isIOS ||
        await channel.invokeMethod<bool>('supported') != true)
      throw PlatformException(
        code: 'unsupported',
        message: 'Vocal reduction requires iOS 18 or later',
      );
    if (item.isLive == true ||
        audioHandler.playbackState.value.processingState !=
            AudioProcessingState.ready)
      throw PlatformException(
        code: 'loading',
        message: 'Wait for this song to finish loading, then try again',
      );
    _request = request;
    _progress = progress;
    var source = audioHandler.audioPlayer.audioSource;
    if (source is ClippingAudioSource) source = source.child;
    if (source is! UriAudioSource)
      throw PlatformException(
        code: 'source',
        message: 'This audio source cannot be separated',
      );
    final uri = source.uri;
    final alias = cacheIdentity(item, uri);
    if (alias != null) {
      final cached = await channel.invokeMethod<String>('cached', {
        'alias': alias,
      });
      if (_request != request) throw const FormatException('Selection changed');
      if (cached != null) {
        progress('Using prepared audio', 1);
        return cached;
      }
    }
    File? temporary;
    final client = http.Client();
    _client = client;
    var complete = false;
    try {
      if (uri.scheme == 'file' && uri.path.endsWith('.musyn-stems.mov')) {
        complete = true;
        return uri.toFilePath();
      }
      // This is inside prepare(), never startup/select(): the user's tap is
      // the only trigger. Model and source downloads can overlap safely.
      final modelReady = channel.invokeMethod<void>('installModel', {
        'request': request,
      });
      unawaited(modelReady.catchError((Object _) {}));
      String path;
      if (uri.scheme == 'file') {
        path = uri.toFilePath();
      } else {
        if (uri.scheme != 'https')
          throw const FormatException('Unsupported audio source');
        progress('Downloading audio locally for separation', 0);
        final directory = await getTemporaryDirectory();
        temporary = File('${directory.path}/musyn-sing-$request.m4a');
        final message = http.Request('GET', uri)
          ..headers.addAll(source.headers ?? {});
        final response = await client
            .send(message)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > 120 * 1024 * 1024)
          throw const FormatException(
            'Audio download unavailable or too large',
          );
        final sink = temporary.openWrite();
        var bytes = 0;
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 20),
          )) {
            if (_request != request)
              throw const FormatException('Selection changed');
            bytes += chunk.length;
            if (bytes > 120 * 1024 * 1024)
              throw const FormatException('Audio exceeds separation limit');
            sink.add(chunk);
            final total = response.contentLength;
            if (total != null && total > 0) {
              progress('Saving audio for Sing Along', bytes / total);
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        path = temporary.path;
      }
      if (_request != request) throw const FormatException('Selection changed');
      final digest = await sha256.bind(File(path).openRead()).first;
      // Content identity prevents a cached mix from another recording being reused.
      final key = sha256.convert(utf8.encode('$digest|light-v1')).toString();
      progress('Finishing Sing Along setup', 0);
      await modelReady;
      if (_request != request) throw const FormatException('Selection changed');
      final result = await channel.invokeMethod<String>('prepare', {
        'path': path,
        'key': key,
        'request': request,
        'alias': alias,
      });
      if (result == null)
        throw const FormatException('No separated audio returned');
      complete = true;
      return result;
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
      if (temporary != null && await temporary.exists())
        await temporary.delete();
      if (!complete && _request == request) await cancel();
    }
  }
}

final _nativeVocals = NativeVocalPreparation();
// Keep the slow experimental path unreachable from public UI and callers.
// Re-enable only after streaming startup and phone acceptance are verified.
final vocalReduction = VocalReductionController(
  available: false,
  prepare: _nativeVocals.prepare,
  install: (id, path) => audioHandler.installVocalStems(id, path),
  mix: (value) => audioHandler.audioPlayer.setMusynVocalLevel(value),
  cancel: _nativeVocals.cancel,
);
