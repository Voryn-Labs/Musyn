import 'package:musified/services/audio/audio_preload_cache.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/logger_service.dart';
import 'package:musified/utilities/app_utils.dart';

/// Stream URL preloading. Only talks to [AudioPreloadCache] + network helpers.
/// Queue position/items are passed in by [AudioHandlerHub] — no queue imports.
class AudioPreloadService {
  AudioPreloadService({
    required this.cache,
    this.lookahead = 1,
    this.maxConcurrent = 1,
    this.fetchTimeout = const Duration(seconds: 8),
    this.fetchUrl,
  });

  final AudioPreloadCache cache;
  final int lookahead;
  final int maxConcurrent;
  final Duration fetchTimeout;
  final Future<String?> Function(Map song)? fetchUrl;

  Future<String?> _fetchUrl(Map song) => fetchUrl != null
      ? fetchUrl!(song)
      : fetchSongStreamUrl(song, song['isLive'] ?? false);

  void cleanupStaleForYtids(Set<String> activeQueueYtids) {
    for (final ytid
        in cache.preloadedYtIds
            .where((id) => !activeQueueYtids.contains(id))
            .toList()) {
      cache.drop(ytid);
    }
    for (final ytid
        in cache.preloadingYtIds
            .where((id) => !activeQueueYtids.contains(id))
            .toList()) {
      cache.drop(ytid);
    }
  }

  Set<String> queueYtids(List<Map> items) {
    return items
        .map((song) => song['ytid']?.toString())
        .where((ytid) => ytid != null && ytid.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  List<Map> upcomingSongs({
    required List<Map> queueItems,
    required int currentIndex,
    required bool offlineModeEnabled,
  }) {
    if (offlineModeEnabled) return [];

    final songs = <Map>[];
    for (var i = 1; i <= lookahead; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex >= queueItems.length) break;

      final nextSong = queueItems[nextIndex];
      final ytid = nextSong['ytid']?.toString();
      if (ytid == null || ytid.isEmpty) continue;
      if (isSongAlreadyOffline(ytid)) continue;
      if (cache.preloadedYtIds.contains(ytid)) continue;
      if (cache.preloadingYtIds.contains(ytid)) continue;
      songs.add(nextSong);
    }
    return songs;
  }

  Future<void> preloadSequentially(
    List<Map> songs, {
    required bool Function() isLoadInProgress,
    required Future<void> Function(Map song) preloadOne,
  }) async {
    for (final song in songs) {
      if (isLoadInProgress()) return;
      while (cache.activeCount >= maxConcurrent) {
        if (isLoadInProgress()) return;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ytid = song['ytid']?.toString();
      if (ytid == null || cache.preloadingYtIds.contains(ytid)) continue;
      await preloadOne(song);
    }
  }

  Future<void> preloadSingle(
    Map nextSong, {
    required bool offlineModeEnabled,
    required bool Function() isLoadInProgress,
  }) async {
    final ytid = nextSong['ytid']?.toString();
    if (ytid == null || offlineModeEnabled || isLoadInProgress()) return;

    final ticket = cache.begin(ytid, maxConcurrent: maxConcurrent);
    if (ticket == null) return;
    String? preloadUrl;
    var mayPublish = false;
    // Clone the song so _fetchUrl (→ fetchSongStreamUrl) doesn't mutate the
    // queue's live song map with resolved* fields while a different track plays.
    final songCopy = Map<String, dynamic>.from(
      nextSong.map((k, v) => MapEntry(k.toString(), v)),
    );
    final request = Future<String?>.sync(() => _fetchUrl(songCopy)).then(
      (url) {
        mayPublish = cache.finish(ytid, ticket);
        return url;
      },
      onError: (Object error, StackTrace stackTrace) {
        cache.finish(ytid, ticket);
        Error.throwWithStackTrace(error, stackTrace);
      },
    );

    try {
      preloadUrl = await request.timeout(
        fetchTimeout,
        onTimeout: () {
          logger.log('Preload timeout for song $ytid');
          return null;
        },
      );
      if (isLoadInProgress()) {
        logger.log('Preload aborted after fetch for $ytid');
        preloadUrl = null;
        return;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error preloading song $ytid',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (mayPublish && preloadUrl != null && preloadUrl.isNotEmpty) {
        final usableYoutube = isUsableYoutubePlaybackUrl(preloadUrl);
        final usableSaavn = isUsableJiosaavnPlaybackUrl(preloadUrl);
        if (usableYoutube || usableSaavn) {
          cache.preloadedYtIds.add(ytid);
          cache.streamUrls[ytid] = preloadUrl;
          cache.trimIfNeeded();
          nextSong['_preloadedStreamUrl'] = preloadUrl;
          logger.log(
            'Preloaded stream for $ytid',
            data: {
              'host': Uri.tryParse(preloadUrl)?.host ?? '-',
              'dur': usableYoutube
                  ? youtubeStreamDurationSeconds(
                          Uri.parse(preloadUrl),
                        )?.toString() ??
                        '-'
                  : '-',
            },
          );
        } else {
          logger.log('Preload URL unusable for $ytid (expired or invalid)');
        }
      }
    }
  }
}
