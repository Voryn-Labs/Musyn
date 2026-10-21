// ignore_for_file: cascade_invocations
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/audio/player_artwork_cache.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/utilities/artwork_provider.dart';

// Cache durations for different types of data
const Duration songCacheDuration = Duration(hours: 1, minutes: 30);
const Duration playlistCacheDuration = Duration(hours: 5);
const Duration searchCacheDuration = Duration(days: 1);
const Duration defaultCacheDuration = Duration(days: 2);

// In-memory cache for frequently accessed items
final _memoryCache = <String, _CacheEntry>{};

class _CacheEntry {
  _CacheEntry(this.data, this.timestamp, this.lifetime);
  final dynamic data;
  final DateTime timestamp;
  final Duration lifetime;

  bool isValid(Duration cacheDuration) {
    return DateTime.now().difference(timestamp) < cacheDuration;
  }
}

dynamic _copyCacheValue(dynamic value) {
  if (value is Uint8List) return Uint8List.fromList(value);
  if (value is Map)
    return value.map((key, item) => MapEntry(key, _copyCacheValue(item)));
  if (value is List) return value.map(_copyCacheValue).toList();
  return value;
}

void _pruneMemoryCache() =>
    _memoryCache.removeWhere((_, entry) => !entry.isValid(entry.lifetime));

DateTime? _parseCacheDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

// Cap kept intentionally modest for LiveContainer / personal devices.
const int _maxMemoryCacheSize = 200;
const int _memoryCacheTrimSize = 50;

void _setMemoryCacheEntry(String key, _CacheEntry entry) {
  _pruneMemoryCache();
  _memoryCache
    ..remove(key)
    ..[key] = entry;
  _trimMemoryCacheIfNeeded();
}

void _touchMemoryCacheEntry(String key) {
  final entry = _memoryCache.remove(key);
  if (entry != null) {
    _memoryCache[key] = entry;
  }
}

void _trimMemoryCacheIfNeeded() {
  if (_memoryCache.length > _maxMemoryCacheSize) {
    final keysToRemove = _memoryCache.keys.take(_memoryCacheTrimSize).toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }
  }
}

/// Bounds Flutter's in-memory decoded-image cache (not Hive / not downloads).
void configureImageMemoryBudget() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 48 << 20; // ~48 MB
}

Future<void> addOrUpdateData<T>(String category, String key, T value) async {
  final _box = await _openBox(category);

  if (category == 'cache') {
    final snapshot = _copyCacheValue(value);
    await _box.putAll({key: snapshot, '${key}_date': DateTime.now()});
    final cacheKey = '${category}_$key';
    _setMemoryCacheEntry(
      cacheKey,
      _CacheEntry(
        _copyCacheValue(snapshot),
        DateTime.now(),
        _getCacheDurationForKey(key),
      ),
    );
  } else {
    await _box.put(key, value);
  }
}

Future<dynamic> getData(
  String category,
  String key, {
  dynamic defaultValue,
  Duration? cachingDuration,
}) async {
  // Set appropriate cache duration based on key
  cachingDuration ??= _getCacheDurationForKey(key);

  // Check memory cache first
  _pruneMemoryCache();
  final cacheKey = '${category}_$key';
  final memCacheEntry = _memoryCache[cacheKey];
  if (memCacheEntry != null && memCacheEntry.isValid(cachingDuration)) {
    _touchMemoryCacheEntry(cacheKey);
    return _copyCacheValue(memCacheEntry.data);
  }
  _trimMemoryCacheIfNeeded();

  final _box = await _openBox(category);
  if (category == 'cache') {
    final cacheIsValid = isCacheValid(_box, key, cachingDuration);
    if (!cacheIsValid) {
      await deleteData(category, key);
      await deleteData(category, '${key}_date');
      return defaultValue;
    }
  }

  final data = await _box.get(key, defaultValue: defaultValue);

  // Store in memory cache for faster access next time
  if (data != null && category == 'cache') {
    final timestamp =
        _parseCacheDate(await _box.get('${key}_date')) ?? DateTime.now();
    _setMemoryCacheEntry(
      cacheKey,
      _CacheEntry(_copyCacheValue(data), timestamp, cachingDuration),
    );
  }

  return category == 'cache' ? _copyCacheValue(data) : data;
}

Future<void> deleteData(String category, String key) async {
  _memoryCache
    ..remove('${category}_$key')
    ..remove('${category}_${key}_date');

  final _box = await _openBox(category);
  await _box.delete(key);
  if (category == 'cache') {
    await _box.delete('${key}_date');
    if (key.endsWith('_url')) {
      await _box.delete('${key}_meta');
      await _box.delete('${key}_meta_date');
    }
  }
}

/// Square covers, remote images and decoded images; audio caches stay intact.
Future<void> clearArtworkImageCache() async {
  await PlayerArtworkCache.clear();
  ArtworkProvider.clearCache();
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  await DefaultCacheManager().emptyCache();
}

// Clean up old cache entries to prevent excessive storage usage
Future<void> cleanupOldCacheEntries() async {
  try {
    final cacheBox = await _openBox('cache');
    final now = DateTime.now();

    // Get all keys except the ones with _date suffix
    final keys = cacheBox.keys
        .where((k) => !k.toString().endsWith('_date'))
        .toList();

    for (final key in keys) {
      final dateKey = '${key}_date';
      final row = cacheBox.get(key);
      final automatic =
          key is String && key.startsWith('automatic-artwork:') && row is Map;
      final date = automatic ? row['at'] : cacheBox.get(dateKey);
      final lifetime = automatic
          ? (row['missing'] == true
                ? const Duration(days: 1)
                : const Duration(days: 7))
          : const Duration(days: 2);
      final cacheKey = 'cache_$key';

      if (_parseCacheDate(date) == null) {
        await cacheBox.delete(key);
        await cacheBox.delete(dateKey);
        _memoryCache.remove(cacheKey);
        continue;
      }

      final age = now.difference(_parseCacheDate(date)!);
      // Very old cache entries (older than 2 days) should be removed
      if (age > lifetime) {
        await cacheBox.delete(key);
        await cacheBox.delete(dateKey);
        _memoryCache.remove(cacheKey);
      }
    }

    _pruneMemoryCache();
    await _trimSaavnMatchCache();
  } catch (e, stackTrace) {
    logger.log(
      'Error cleaning up old cache entries',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

const int _saavnMatchCacheMaxKeys = 1500;

Future<void> _trimSaavnMatchCache() async {
  try {
    final box = Hive.isBoxOpen('saavn_match_cache')
        ? Hive.box('saavn_match_cache')
        : await Hive.openBox('saavn_match_cache');
    final excess = box.length - _saavnMatchCacheMaxKeys;
    if (excess <= 0) return;
    final keys = box.keys.take(excess).toList();
    for (final key in keys) {
      await box.delete(key);
    }
  } catch (e) {
    logger.log('Error trimming saavn match cache', error: e);
  }
}

// Check if the cache is still valid based on the caching duration
bool isCacheValid(Box box, String key, Duration cachingDuration) {
  final date = _parseCacheDate(box.get('${key}_date'));
  if (date == null) {
    return false;
  }
  final age = DateTime.now().difference(date);
  return age < cachingDuration;
}

Duration _getCacheDurationForKey(String key) {
  if (key.startsWith('song_') || key.contains('manifest_')) {
    return songCacheDuration;
  } else if (key.startsWith('playlist_') || key.startsWith('playlistSongs')) {
    return playlistCacheDuration;
  } else if (key.startsWith('search_')) {
    return searchCacheDuration;
  }
  return defaultCacheDuration;
}

Future<Box> _openBox(String category) async {
  if (Hive.isBoxOpen(category)) {
    return Hive.box(category);
  } else {
    return Hive.openBox(category);
  }
}

Future<bool> clearAllCache() async {
  try {
    _memoryCache.clear();
    final box = await _openBox('cache');
    await box.deleteAll(
      box.keys
          .where((key) => !key.toString().startsWith('automatic-artwork:'))
          .toList(),
    );
    final saavnBox = Hive.isBoxOpen('saavn_match_cache')
        ? Hive.box('saavn_match_cache')
        : await Hive.openBox('saavn_match_cache');
    await saavnBox.clear();
    return true;
  } catch (e) {
    logger.log('Error clearing cache', error: e);
    return false;
  }
}
