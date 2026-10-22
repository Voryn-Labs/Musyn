import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/library_state.dart';

/// Local-first metadata layered over tracks from every playback provider.
///
/// Records deliberately carry stable IDs, timestamps and tombstones so a
/// future sync backend can merge them without changing the on-device schema.
class SmartLibrary extends ChangeNotifier {
  SmartLibrary._();

  static final instance = SmartLibrary._();
  static const _storageKey = 'smartLibrary.v1';
  static const schemaVersion = 1;

  final Map<String, Map<String, dynamic>> _profiles = {};
  final Map<String, String> _aliases = {};
  final Map<String, Map<String, dynamic>> _tags = {};
  final Map<String, Map<String, dynamic>> _collections = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;
  List<Map<String, dynamic>> get tags => _active(_tags);
  List<Map<String, dynamic>> get collections => _active(_collections);

  Future<void> initialize() async {
    if (_loaded || !Hive.isBoxOpen('user')) return;
    final raw = Hive.box('user').get(_storageKey);
    if (raw is Map) {
      _readMap(raw['profiles'], _profiles);
      _readStrings(raw['aliases'], _aliases);
      _readMap(raw['tags'], _tags);
      _readMap(raw['collections'], _collections);
    }
    _loaded = true;
    notifyListeners();
  }

  Map<String, dynamic> profileFor(Map song) {
    final id = identityFor(song);
    return Map<String, dynamic>.from(_profiles[id] ?? _newProfile(id, song));
  }

  int ratingFor(Map song) => (profileFor(song)['rating'] as num?)?.toInt() ?? 0;
  Set<String> tagIdsFor(Map song) =>
      Set<String>.from(profileFor(song)['tagIds'] as List? ?? const []);
  Set<String> moodsFor(Map song) =>
      Set<String>.from(profileFor(song)['moods'] as List? ?? const []);
  int energyFor(Map song) =>
      (profileFor(song)['energy'] as num?)?.toInt() ?? 1;

  Future<void> rate(Map song, int value) => _update(song, {
    'rating': value.clamp(0, 5),
  });

  Future<void> organize(
    Map song, {
    required Set<String> tagIds,
    required Set<String> moods,
    required int energy,
  }) => _update(song, {
    'tagIds': tagIds.toList(),
    'moods': moods.toList(),
    'energy': energy.clamp(0, 2),
  });

  Future<String> createTag(String name, {int color = 0xFFFFC5A7}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError.value(name, 'name');
    final duplicate = tags.where(
      (tag) => tag['name'].toString().toLowerCase() == clean.toLowerCase(),
    );
    if (duplicate.isNotEmpty) return duplicate.first['id'].toString();
    final id = _localId('tag');
    final now = DateTime.now().toUtc().toIso8601String();
    _tags[id] = {
      'id': id,
      'name': clean,
      'color': color,
      'createdAt': now,
      'updatedAt': now,
      'deletedAt': null,
    };
    await _save();
    return id;
  }

  Future<String> saveCollection({
    String? id,
    required String name,
    required bool matchAll,
    required List<Map<String, dynamic>> rules,
  }) async {
    final recordId = id ?? _localId('collection');
    final now = DateTime.now().toUtc().toIso8601String();
    _collections[recordId] = {
      'id': recordId,
      'name': name.trim(),
      'matchAll': matchAll,
      'rules': rules,
      'createdAt': _collections[recordId]?['createdAt'] ?? now,
      'updatedAt': now,
      'deletedAt': null,
    };
    await _save();
    return recordId;
  }

  Future<void> recordPlayed(Map song) async {
    final profile = _ensure(song);
    profile['playCount'] = ((profile['playCount'] as num?) ?? 0) + 1;
    profile['lastPlayedAt'] = DateTime.now().toUtc().toIso8601String();
    await _touchAndSave(profile);
  }

  Future<void> recordSkipped(Map song) async {
    final profile = _ensure(song);
    profile['skipCount'] = ((profile['skipCount'] as num?) ?? 0) + 1;
    profile['lastSkippedAt'] = DateTime.now().toUtc().toIso8601String();
    await _touchAndSave(profile);
  }

  List<Map> allKnownSongs() {
    final result = <String, Map>{};
    for (final raw in [
      ...userLikedSongsList.value,
      ...userOfflineSongs.value,
      ...userRecentlyPlayed.value,
      for (final playlist in getUserCustomPlaylists())
        ...((playlist['list'] as List?) ?? const []),
    ].whereType<Map>()) {
      result[identityFor(raw)] = Map.from(raw);
    }
    return result.values.toList();
  }

  List<Map> songsForBuiltIn(String id) {
    final songs = allKnownSongs();
    switch (id) {
      case 'five-star':
        return songs.where((s) => ratingFor(s) == 5).toList();
      case 'forgotten':
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        return songs.where((s) {
          final p = profileFor(s);
          final last = DateTime.tryParse(p['lastPlayedAt']?.toString() ?? '');
          return ratingFor(s) >= 4 && (last == null || last.isBefore(cutoff));
        }).toList();
      case 'never-played':
        return songs.where((s) =>
          ((profileFor(s)['playCount'] as num?)?.toInt() ?? 0) == 0).toList();
      case 'offline-favorites':
        final offline = userOfflineSongs.value.whereType<Map>()
            .map(identityFor).toSet();
        return songs.where((s) => offline.contains(identityFor(s)) &&
            (ratingFor(s) >= 4 || _isLiked(s))).toList();
      default:
        return const [];
    }
  }

  List<Map> songsForCollection(Map collection) {
    final rules = (collection['rules'] as List? ?? const []).whereType<Map>();
    final all = collection['matchAll'] != false;
    return allKnownSongs().where((song) {
      final matches = rules.map((rule) => _matches(song, rule));
      return all ? matches.every((v) => v) : matches.any((v) => v);
    }).toList();
  }

  /// Rating-aware shuffle with a recent-play penalty and no duplicate IDs.
  List<Map> smartShuffle(Iterable<Map> input, {int? seed}) {
    final random = Random(seed);
    final candidates = <String, Map>{
      for (final song in input) identityFor(song): Map.from(song),
    }.values.toList();
    final weighted = <({Map song, double key})>[];
    for (final song in candidates) {
      final p = profileFor(song);
      final rating = (p['rating'] as num?)?.toDouble() ?? 0;
      final skips = (p['skipCount'] as num?)?.toDouble() ?? 0;
      final last = DateTime.tryParse(p['lastPlayedAt']?.toString() ?? '');
      final recentPenalty = last != null &&
              DateTime.now().difference(last) < const Duration(days: 7)
          ? 0.35
          : 1.0;
      final weight = max(0.15, (1 + rating * .32 - skips * .06) * recentPenalty);
      final key = pow(random.nextDouble().clamp(.00001, .99999), 1 / weight)
          .toDouble();
      weighted.add((song: song, key: key));
    }
    weighted.sort((a, b) => b.key.compareTo(a.key));
    return weighted.map((e) => e.song).toList();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(_snapshot());

  Future<void> importJson(String text) async {
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('Invalid library backup');
    _readMap(decoded['profiles'], _profiles, clear: true);
    _readStrings(decoded['aliases'], _aliases, clear: true);
    _readMap(decoded['tags'], _tags, clear: true);
    _readMap(decoded['collections'], _collections, clear: true);
    await _save();
  }

  String identityFor(Map song) {
    final aliases = _sourceAliases(song);
    for (final alias in aliases) {
      final resolved = _aliases[alias];
      if (resolved != null) return resolved;
    }
    final id = aliases.firstWhere(
      (a) => a.startsWith('youtube:'),
      orElse: () => aliases.first,
    );
    for (final alias in aliases) _aliases[alias] = id;
    return id;
  }

  Future<void> _update(Map song, Map<String, dynamic> values) async {
    final profile = _ensure(song)..addAll(values);
    await _touchAndSave(profile);
  }

  Map<String, dynamic> _ensure(Map song) {
    final id = identityFor(song);
    final profile = _profiles.putIfAbsent(id, () => _newProfile(id, song));
    profile['snapshot'] = Map<String, dynamic>.from(song);
    for (final alias in _sourceAliases(song)) _aliases[alias] = id;
    return profile;
  }

  Map<String, dynamic> _newProfile(String id, Map song) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': id,
      'schemaVersion': schemaVersion,
      'snapshot': Map<String, dynamic>.from(song),
      'rating': 0,
      'tagIds': <String>[],
      'moods': <String>[],
      'energy': 1,
      'playCount': 0,
      'skipCount': 0,
      'createdAt': now,
      'updatedAt': now,
      'deletedAt': null,
    };
  }

  Future<void> _touchAndSave(Map<String, dynamic> profile) async {
    profile['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _save();
  }

  Future<void> _save() async {
    if (!Hive.isBoxOpen('user')) return;
    await Hive.box('user').put(_storageKey, _snapshot());
    notifyListeners();
  }

  Map<String, dynamic> _snapshot() => {
    'schemaVersion': schemaVersion,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'profiles': _profiles,
    'aliases': _aliases,
    'tags': _tags,
    'collections': _collections,
  };

  bool _matches(Map song, Map rule) {
    final p = profileFor(song);
    final field = rule['field']?.toString();
    final value = rule['value'];
    return switch (field) {
      'rating' => ratingFor(song) >= ((value as num?)?.toInt() ?? 0),
      'tag' => tagIdsFor(song).contains(value?.toString()),
      'mood' => moodsFor(song).contains(value?.toString()),
      'downloaded' => userOfflineSongs.value.whereType<Map>()
          .any((s) => identityFor(s) == identityFor(song)),
      'favorite' => _isLiked(song),
      'source' => song['source']?.toString() == value?.toString(),
      'playCount' => ((p['playCount'] as num?)?.toInt() ?? 0) >=
          ((value as num?)?.toInt() ?? 0),
      _ => false,
    };
  }

  bool _isLiked(Map song) {
    final id = identityFor(song);
    return userLikedSongsList.value.whereType<Map>()
        .any((liked) => identityFor(liked) == id);
  }

  List<String> _sourceAliases(Map song) {
    final result = <String>[];
    void add(String prefix, dynamic value) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) result.add('$prefix:$text');
    }
    add('youtube', song['ytid']);
    add('saavn', song['saavnId']);
    final title = _normalize(song['title']);
    final artist = _normalize(song['artist']);
    final duration = ((num.tryParse('${song['duration']}') ?? 0) / 5).round();
    final fingerprint = sha1.convert(utf8.encode('$title|$artist|$duration'));
    result.add('fingerprint:$fingerprint');
    return result;
  }

  String _normalize(dynamic value) => value
      ?.toString()
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*(feat|remaster)[^)]*\)'), '')
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim() ?? '';

  String _localId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  List<Map<String, dynamic>> _active(
    Map<String, Map<String, dynamic>> source,
  ) => source.values
      .where((item) => item['deletedAt'] == null)
      .map(Map<String, dynamic>.from)
      .toList();

  void _readMap(
    dynamic raw,
    Map<String, Map<String, dynamic>> target, {
    bool clear = false,
  }) {
    if (clear) target.clear();
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        target[entry.key.toString()] =
            Map<String, dynamic>.from(entry.value as Map);
      }
    }
  }

  void _readStrings(dynamic raw, Map<String, String> target, {bool clear = false}) {
    if (clear) target.clear();
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      target[entry.key.toString()] = entry.value.toString();
    }
  }
}
