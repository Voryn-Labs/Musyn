import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musyn/services/audio/audio_playback_install.dart';
import 'package:musyn/services/audio/playback_source.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/utilities/app_utils.dart';

typedef PlaybackLogFn =
    void Function(String message, {Map<String, Object?>? extra});

/// Resolves URLs, builds sources, and installs them in [audioPlayer].
/// No queue imports — the handler passes source metadata and callbacks.
class AudioPlaybackCoordinator {
  AudioPlaybackCoordinator({
    required this.audioPlayer,
    this.offlineTransitionTimeout = const Duration(seconds: 6),
    this.streamTransitionTimeout = const Duration(seconds: 12),
  });

  final AudioPlayer audioPlayer;
  final Duration offlineTransitionTimeout;
  final Duration streamTransitionTimeout;

  bool sourceSwitchInFlight = false;
  bool lastInstalledWasOffline = false;
  bool lastInstalledWasClipped = false;
  int? installedSourceTransitionId;
  String? lastError;

  void resetInstallState() {
    lastInstalledWasOffline = false;
    lastInstalledWasClipped = false;
    installedSourceTransitionId = null;
    lastError = null;
  }

  /// Detach the current AVPlayer item before installing a new stream URL.
  ///
  /// Previously this called `audioPlayer.stop()`, which deactivated the iOS
  /// audio session. A deactivated session causes iOS to suspend the app while
  /// backgrounded — killing lock-screen playback between tracks.
  ///
  /// Now we `pause()` instead: the old source stays attached (keeping the
  /// session alive) until `setAudioSources([newSource])` atomically replaces
  /// it. This is used only during explicit failure recovery.
  Future<void> detachCurrentStream() async {
    installedSourceTransitionId = null;
    if (audioPlayer.audioSource == null) return;
    try {
      if (audioPlayer.playing) {
        await audioPlayer.pause().timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      logger.log('detachCurrentStream pause failed: $e');
    }
  }

  /// just_audio [AudioPlayer.play] completes when playback *stops*, not when it
  /// starts — never await it with a short timeout. Poll until AVPlayer is
  /// actually playing/buffering instead.
  Future<bool> beginPlaybackAfterInstall({
    required bool Function(int?) isStale,
    required PlaybackLogFn logPlayer,
    int? transitionId,
    Duration timeout = const Duration(seconds: 15),
    required bool Function() shouldPlay,
  }) async {
    if (isStale(transitionId) || !shouldPlay()) return false;
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e, st) {
      logger.log('setActive before play failed', error: e, stackTrace: st);
    }

    if (isStale(transitionId) || !shouldPlay()) return false;
    unawaited(
      audioPlayer.play().catchError((Object e, StackTrace st) {
        logger.log('play() error', error: e, stackTrace: st);
        lastError = e.toString();
      }),
    );

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (isStale(transitionId) || !shouldPlay()) return false;

      final state = audioPlayer.processingState;
      if (audioPlayer.playing &&
          state != ProcessingState.idle &&
          state != ProcessingState.completed) {
        lastError = null;
        logPlayer(
          'playback started',
          extra: {'state': state.name, 'pos': audioPlayer.position.inSeconds},
        );
        return true;
      }

      if (state == ProcessingState.loading ||
          state == ProcessingState.buffering) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        continue;
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final playing = audioPlayer.playing;
    if (playing) {
      lastError = null;
    }
    logPlayer(
      'playback start wait finished',
      extra: {'playing': playing, 'state': audioPlayer.processingState.name},
    );
    return playing;
  }

  Future<bool> resolveOfflineAndSetPaths(Map songData) async {
    try {
      final ytid = songData['ytid']?.toString();
      if (ytid != null && ytid.isNotEmpty) {
        final offlineSong = getOfflineSongByYtid(ytid);
        if (offlineSong.isNotEmpty) {
          final audioPath = offlineSong['audioPath']?.toString();
          if (audioPath != null && audioPath.isNotEmpty) {
            final f = File(audioPath);
            if (await f.exists() && await f.length() > 8192) {
              songData['audioPath'] = audioPath;
              if (offlineSong['artworkPath'] != null) {
                songData['artworkPath'] = offlineSong['artworkPath'];
              }
              logger.log(
                'Offline file OK',
                data: {
                  'ytid': ytid,
                  'bytes': await f.length(),
                  'path': audioPath,
                },
              );
              return true;
            }
            logger.log(
              'Offline file unusable',
              data: {
                'ytid': ytid,
                'exists': await f.exists(),
                'bytes': await f.exists() ? await f.length() : 0,
                'path': audioPath,
              },
            );
          }
        }
      }
    } catch (e, st) {
      logger.log(
        'Error while checking offline songs',
        error: e,
        stackTrace: st,
      );
    }

    try {
      final path = songData['audioPath']?.toString();
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists()) return true;
      }
    } catch (_) {}

    return false;
  }

  Future<String?> getOfflineSongUrl(
    Map song,
    List<Map<dynamic, dynamic>> offlineLibrary,
  ) async {
    final audioPath = song['audioPath']?.toString();
    if (audioPath == null || audioPath.isEmpty) {
      logger.log('Missing audioPath for offline song: ${song['ytid']}');
      return null;
    }

    final file = File(audioPath);
    if (await file.exists()) {
      final bytes = await file.length();
      if (bytes > 8192) return audioPath;
      logger.log(
        'Offline audio file too small',
        data: {'ytid': song['ytid'], 'bytes': bytes, 'path': audioPath},
      );
    }

    logger.log('Offline audio file not found: $audioPath');

    final offlineSong = offlineLibrary.firstWhere(
      (s) => s['ytid'] == song['ytid'],
      orElse: () => <String, dynamic>{},
    );

    if (offlineSong.isNotEmpty && offlineSong['audioPath'] != null) {
      final fallbackPath = offlineSong['audioPath']?.toString();
      if (fallbackPath == null || fallbackPath.isEmpty) return null;
      final fallbackFile = File(fallbackPath);
      if (await fallbackFile.exists()) {
        song['audioPath'] = fallbackPath;
        return fallbackPath;
      }
    }

    return null;
  }

  Future<String?> getPlaybackUrl(
    Map song,
    Map<String, String> preloadedUrls, {
    required bool isOffline,
    Map<String, Map<String, dynamic>> preloadedMetadata = const {},
    bool Function()? abandon,
  }) async {
    if (isOffline) {
      return getOfflineSongUrl(
        song,
        userOfflineSongs.value.cast<Map<dynamic, dynamic>>(),
      );
    }

    final ytid = song['ytid']?.toString();

    void rejectStale(String source, String url) {
      logger.log(
        'Rejecting stale $source stream URL for $ytid',
        data: {'expire': Uri.tryParse(url)?.queryParameters['expire'] ?? '-'},
      );
      song
        ..remove('_preloadedStreamUrl')
        ..remove('_preloadedStreamMetadata');
      if (ytid != null) {
        preloadedUrls.remove(ytid);
        if (preloadedMetadata.containsKey(ytid)) preloadedMetadata.remove(ytid);
      }
    }

    final warmed = song['_preloadedStreamUrl']?.toString();
    if (warmed != null && warmed.isNotEmpty) {
      final prepared = song['_preloadedStreamMetadata'];
      final candidate = Map<dynamic, dynamic>.from(song);
      if (prepared is Map) candidate.addAll(prepared);
      // Explicit source selection still wins over the prepared descriptor.
      if (streamUrlMatchesPreferredSource(warmed, candidate)) {
        if (prepared is Map) {
          for (final entry in prepared.entries) {
            if (entry.key is String) song[entry.key as String] = entry.value;
          }
        }
        logger.log('Using pre-warmed stream URL for $ytid');
        return warmed;
      }
      rejectStale('pre-warmed', warmed);
    }
    if (ytid != null && preloadedUrls.containsKey(ytid)) {
      final cached = preloadedUrls[ytid]!;
      final prepared = preloadedMetadata[ytid];
      final candidate = Map<dynamic, dynamic>.from(song);
      if (prepared != null) candidate.addAll(prepared);
      if (streamUrlMatchesPreferredSource(cached, candidate)) {
        if (prepared != null) song.addAll(prepared);
        logger.log('Using preloaded stream URL for $ytid');
        return cached;
      }
      rejectStale('preloaded', cached);
    }

    return fetchSongStreamUrl(song, song['isLive'] ?? false, abandon: abandon);
  }

  Future<PlaybackSource?> resolvePlaybackSource(
    Map songData, {
    required bool offlineModeEnabled,
    required Map<String, String> preloadedUrls,
    Map<String, Map<String, dynamic>> preloadedMetadata = const {},
    bool Function()? abandon,
  }) async {
    if (abandon?.call() == true) return null;
    final forceSource = songData['forceSource']?.toString();
    final skipOffline =
        !offlineModeEnabled &&
        (forceSource == 'youtube' || forceSource == 'jiosaavn');

    if (skipOffline) {
      logger.log(
        'Skipping local file — explicit source=$forceSource',
        data: {'ytid': songData['ytid'], 'title': songData['title']},
      );
      songData
        ..remove('isOffline')
        ..remove('audioPath');
    } else {
      final isOffline = await resolveOfflineAndSetPaths(songData);
      if (isOffline) {
        songData['isOffline'] = true;
        songData['resolvedSource'] = 'offline';
        final songUrl = await getOfflineSongUrl(
          songData,
          userOfflineSongs.value.cast<Map<dynamic, dynamic>>(),
        );
        if (songUrl != null && songUrl.isNotEmpty) {
          logger.log(
            'Playing from local file',
            data: {'ytid': songData['ytid'], 'path': songUrl},
          );
          return PlaybackSource(songUrl: songUrl, isOffline: true);
        }
        if (offlineModeEnabled || forceSource == 'offline') {
          logger.log(
            'Offline file missing for ${songData['ytid']} while offline mode on',
          );
          return null;
        }
        logger.log(
          'Offline file missing for ${songData['ytid']}, falling back to online',
        );
      }

      if (!isOffline && (offlineModeEnabled || forceSource == 'offline')) {
        logger.log(
          'Offline mode enabled and no local file found for ${songData['ytid']}',
        );
        return null;
      }
    }

    if (abandon?.call() == true) return null;

    final songUrl = await getPlaybackUrl(
      songData,
      preloadedUrls,
      preloadedMetadata: preloadedMetadata,
      isOffline: false,
      abandon: abandon,
    ).timeout(const Duration(seconds: 36));

    if (abandon?.call() == true) return null;

    if (songUrl == null || songUrl.isEmpty) {
      logger.log(
        'Failed to get song URL for ${songData['ytid']}',
        data: {'force': forceSource ?? '-', 'title': songData['title']},
      );
      return null;
    }

    return PlaybackSource(songUrl: songUrl, isOffline: false);
  }

  Future<bool> setAudioSourceAndPlay({
    required Map song,
    required AudioSource audioSource,
    required String songUrl,
    required bool isOffline,
    required bool Function(int?) isStale,
    required PlaybackLogFn logPlayer,
    required bool Function() offlineModeEnabled,
    required bool Function() shouldPlay,
    required void Function(Duration duration) onDurationKnown,
    required void Function() onPlaybackStateChanged,
    required Future<void> Function(int? transitionId) ensureActuallyPlaying,
    required Future<void> Function(Map song) onRecentlyPlayed,
    required void Function() schedulePreload,
    String? mediaId,
    bool allowOnlineRetry = true,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    // just_audio interrupts an older native load when setAudioSources is
    // called again. Serializing here prevented that cancellation and made
    // every quick skip wait for the abandoned network request.
    return _setAudioSourceAndPlay(
      song: song,
      audioSource: audioSource,
      songUrl: songUrl,
      isOffline: isOffline,
      isStale: isStale,
      logPlayer: logPlayer,
      offlineModeEnabled: offlineModeEnabled,
      shouldPlay: shouldPlay,
      onDurationKnown: onDurationKnown,
      onPlaybackStateChanged: onPlaybackStateChanged,
      ensureActuallyPlaying: ensureActuallyPlaying,
      onRecentlyPlayed: onRecentlyPlayed,
      schedulePreload: schedulePreload,
      mediaId: mediaId,
      allowOnlineRetry: allowOnlineRetry,
      transitionId: transitionId,
      resumeAt: resumeAt,
    );
  }

  Future<bool> _setAudioSourceAndPlay({
    required Map song,
    required AudioSource audioSource,
    required String songUrl,
    required bool isOffline,
    required bool Function(int?) isStale,
    required PlaybackLogFn logPlayer,
    required bool Function() offlineModeEnabled,
    required bool Function() shouldPlay,
    required void Function(Duration duration) onDurationKnown,
    required void Function() onPlaybackStateChanged,
    required Future<void> Function(int? transitionId) ensureActuallyPlaying,
    required Future<void> Function(Map song) onRecentlyPlayed,
    required void Function() schedulePreload,
    String? mediaId,
    bool allowOnlineRetry = true,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    try {
      final urlHost = isOffline
          ? 'file:${songUrl.split('/').last}'
          : (Uri.tryParse(songUrl)?.host ?? 'invalid-url');
      logger.log(
        'Playing [${song['title']}] source=${song['resolvedSource']} host=$urlHost',
      );

      if (isStale(transitionId)) return false;

      // Keep playback intent and the audio session active across replacement.
      // The native player replaces its item and aborts any previous load;
      // an extra pause/activation round-trip only adds silence to every skip.
      if (!shouldPlay() && audioPlayer.playing) {
        await audioPlayer.pause();
        if (isStale(transitionId)) return false;
      }

      final installSource = audioSource;

      final needsHardReset = isOffline || lastInstalledWasOffline;

      logPlayer(
        'setAudioSources',
        extra: {
          'title': song['title'],
          'source': song['resolvedSource'],
          'offline': isOffline,
          'host': urlHost,
          'clip': audioSource is ClippingAudioSource,
          'hardReset': needsHardReset,
          'preload': true,
        },
      );

      final installClock = Stopwatch()..start();
      await audioPlayer
          .setAudioSources(
            [installSource],
            initialPosition: Duration.zero,
            initialIndex: 0,
          )
          .timeout(
            isOffline ? offlineTransitionTimeout : streamTransitionTimeout,
          );

      logPlayer(
        'Source installed',
        extra: {
          'title': song['title'],
          'source': song['resolvedSource'],
          'playerDur': audioPlayer.duration?.inSeconds,
          'loadMs': installClock.elapsedMilliseconds,
        },
      );

      if (isStale(transitionId)) return false;

      installedSourceTransitionId = transitionId;
      lastInstalledWasOffline = isOffline;
      lastInstalledWasClipped =
          installSource is ClippingAudioSource ||
          audioSource is ClippingAudioSource;

      if (audioPlayer.duration != null) {
        final catalog = parseSongDuration(song['duration']);
        if (catalog != null &&
            catalog > const Duration(seconds: 5) &&
            audioPlayer.duration! > catalog + const Duration(seconds: 5)) {
          onDurationKnown(catalog);
        } else {
          onDurationKnown(audioPlayer.duration!);
        }
      }

      if (resumeAt != null && resumeAt > Duration.zero) {
        final duration = audioPlayer.duration;
        final target = duration != null && resumeAt > duration
            ? duration
            : resumeAt;
        try {
          await audioPlayer.seek(target);
        } catch (e, st) {
          logger.log(
            'Seek to resume position failed',
            error: e,
            stackTrace: st,
          );
        }
      }

      if (isStale(transitionId)) return false;
      if (!shouldPlay()) {
        await audioPlayer.pause();
        onPlaybackStateChanged();
        return true;
      }
      final started = await beginPlaybackAfterInstall(
        isStale: isStale,
        logPlayer: logPlayer,
        transitionId: transitionId,
        shouldPlay: shouldPlay,
      );
      if (isStale(transitionId)) return false;
      if (!shouldPlay()) {
        await audioPlayer.pause();
        onPlaybackStateChanged();
        return true;
      }
      if (!started) return false;

      unawaited(ensureActuallyPlaying(transitionId));
      unawaited(onRecentlyPlayed(song));

      onPlaybackStateChanged();
      // Warm the next track URL while this one is still playing — critical for
      // lock-screen continuity (iOS suspends on silence between tracks).
      schedulePreload();

      return true;
    } catch (e, stackTrace) {
      if (isStale(transitionId)) return false;
      logPlayer(
        'Error setting audio source',
        extra: {'title': song['title'], 'offline': isOffline},
      );
      logger.log(
        'Error setting audio source',
        error: e,
        stackTrace: stackTrace,
      );

      if (isOffline) {
        try {
          if (offlineModeEnabled()) return false;
        } catch (_) {}

        return attemptOfflineFallback(
          song: song,
          isStale: isStale,
          logPlayer: logPlayer,
          offlineModeEnabled: offlineModeEnabled,
          shouldPlay: shouldPlay,
          onDurationKnown: onDurationKnown,
          onPlaybackStateChanged: onPlaybackStateChanged,
          ensureActuallyPlaying: ensureActuallyPlaying,
          onRecentlyPlayed: onRecentlyPlayed,
          schedulePreload: schedulePreload,
          mediaId: mediaId,
          transitionId: transitionId,
          resumeAt: resumeAt,
        );
      }

      if (allowOnlineRetry) {
        if (offlineModeEnabled()) {
          lastError = e.toString();
          return false;
        }
        final songId = song['ytid']?.toString();
        if (songId != null && songId.isNotEmpty) {
          song.remove('_preloadedStreamUrl');
          await invalidateSongStreamCache(songId);

          final refreshedUrl = await fetchSongStreamUrl(
            song,
            song['isLive'] ?? false,
          );

          if (refreshedUrl != null && refreshedUrl.isNotEmpty) {
            final refreshedSource = await AudioPlaybackInstall.buildSource(
              song,
              refreshedUrl,
              false,
            );

            if (refreshedSource != null) {
              return _setAudioSourceAndPlay(
                song: song,
                audioSource: refreshedSource,
                songUrl: refreshedUrl,
                isOffline: false,
                isStale: isStale,
                logPlayer: logPlayer,
                offlineModeEnabled: offlineModeEnabled,
                shouldPlay: shouldPlay,
                onDurationKnown: onDurationKnown,
                onPlaybackStateChanged: onPlaybackStateChanged,
                ensureActuallyPlaying: ensureActuallyPlaying,
                onRecentlyPlayed: onRecentlyPlayed,
                schedulePreload: schedulePreload,
                mediaId: mediaId,
                allowOnlineRetry: false,
                transitionId: transitionId,
                resumeAt: resumeAt,
              );
            }
          }
        }
      }

      lastError = e.toString();
      if (!isStale(transitionId)) await _recoverPlayerAfterLoadFailure();
      return false;
    }
  }

  /// Clears a poisoned AVPlayer session after -1004 / timeout load failures.
  /// Uses pause() (via detachCurrentStream) instead of stop() so the iOS
  /// audio session stays alive and lock-screen controls remain functional.
  Future<void> recoverPlayerAfterLoadFailure({bool Function()? abandon}) async {
    if (abandon?.call() == true) return;
    await _recoverPlayerAfterLoadFailure();
  }

  Future<void> _recoverPlayerAfterLoadFailure() async {
    installedSourceTransitionId = null;
    lastInstalledWasOffline = false;
    lastInstalledWasClipped = false;
    await detachCurrentStream();
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e) {
      logger.log('recoverPlayerAfterLoadFailure setActive failed: $e');
    }
  }

  Future<bool> attemptOfflineFallback({
    required Map song,
    required bool Function(int?) isStale,
    required PlaybackLogFn logPlayer,
    required bool Function() offlineModeEnabled,
    required bool Function() shouldPlay,
    required void Function(Duration duration) onDurationKnown,
    required void Function() onPlaybackStateChanged,
    required Future<void> Function(int? transitionId) ensureActuallyPlaying,
    required Future<void> Function(Map song) onRecentlyPlayed,
    required void Function() schedulePreload,
    String? mediaId,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    if (offlineModeEnabled() ||
        isStale(transitionId) ||
        song['forceSource'] == 'offline')
      return false;

    final onlineUrl = await fetchSongStreamUrl(song, song['isLive'] ?? false);
    if (onlineUrl != null && onlineUrl.isNotEmpty) {
      final onlineSource = await AudioPlaybackInstall.buildSource(
        song,
        onlineUrl,
        false,
      );
      if (onlineSource != null) {
        return _setAudioSourceAndPlay(
          song: song,
          audioSource: onlineSource,
          songUrl: onlineUrl,
          isOffline: false,
          isStale: isStale,
          logPlayer: logPlayer,
          offlineModeEnabled: offlineModeEnabled,
          shouldPlay: shouldPlay,
          onDurationKnown: onDurationKnown,
          onPlaybackStateChanged: onPlaybackStateChanged,
          ensureActuallyPlaying: ensureActuallyPlaying,
          onRecentlyPlayed: onRecentlyPlayed,
          schedulePreload: schedulePreload,
          mediaId: mediaId,
          transitionId: transitionId,
          resumeAt: resumeAt,
        );
      }
    }
    return false;
  }
}
