import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/playback_controller.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/lock_screen_lyrics.dart';
import 'package:musyn/services/motion_artwork.dart';
import 'package:musyn/utilities/mediaitem.dart';

/// audio_service does not expose MPFeedbackCommand on iOS. Keep the native
/// command in sync with the same local favorites store used by the player.
class RemoteFavorites {
  RemoteFavorites({
    this.channel = const MethodChannel('com.vorynlabs.musyn/remote_favorites'),
  });
  final MethodChannel channel;
  final _lyrics = LockScreenLyrics(
    load: (item) => getSongLyrics(item.artist, item.title),
  );
  StreamSubscription<MediaItem?>? _subscription;
  PlaybackController? _handler;

  void start(PlaybackController handler) {
    _subscription?.cancel();
    userLikedSongsList.removeListener(_sync);
    motionArtworkEnabled.removeListener(_sync);
    MotionArtwork.instance.removeListener(_sync);
    lockScreenLyricsEnabled.removeListener(_sync);
    _handler = handler;
    channel.setMethodCallHandler(handleCommand);
    _subscription = handler.mediaItem.listen((_) => _sync());
    userLikedSongsList.addListener(_sync);
    motionArtworkEnabled.addListener(_sync);
    MotionArtwork.instance.addListener(_sync);
    lockScreenLyricsEnabled.addListener(_sync);
    _sync();
  }

  String? _id(MediaItem? item) =>
      item == null ? null : item.extras?['ytid']?.toString() ?? item.id;

  void _sync() {
    MotionArtwork.instance.select(_handler?.mediaItem.valueOrNull);
    _lyrics.select(
      _handler?.mediaItem.valueOrNull,
      enabled: lockScreenLyricsEnabled.value,
    );
    final id = _id(_handler?.mediaItem.valueOrNull);
    unawaited(
      channel
          .invokeMethod<void>('setState', {
            'trackId': id,
            'mediaId': _handler?.mediaItem.valueOrNull?.id,
            'motionEnabled': motionArtworkEnabled.value,
            'motionPath': id == null
                ? null
                : MotionArtwork.instance.fileFor(id),
            // Read the published list directly: its synchronous notification precedes
            // the lookup-cache refresh inside updateSongLikeStatus.
            'liked':
                id != null &&
                userLikedSongsList.value.whereType<Map>().any(
                  (song) => song['ytid']?.toString() == id,
                ),
          })
          .catchError((Object _) {}),
    );
  }

  Future<bool> handleCommand(MethodCall call) async {
    if (call.method != 'setFavorite' || call.arguments is! Map) return false;
    final args = call.arguments as Map;
    final item = _handler?.mediaItem.valueOrNull;
    final id = _id(item);
    final liked = args['liked'];
    // A delayed system action must not favorite a newly selected track.
    if (item == null || id == null || args['trackId'] != id || liked is! bool)
      return false;
    await updateSongLikeStatus(id, liked, songData: mediaItemToMap(item));
    _sync();
    return isSongAlreadyLiked(id) == liked;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    userLikedSongsList.removeListener(_sync);
    motionArtworkEnabled.removeListener(_sync);
    MotionArtwork.instance.removeListener(_sync);
    lockScreenLyricsEnabled.removeListener(_sync);
    _lyrics.dispose();
    _handler = null;
    _sync();
    channel.setMethodCallHandler(null);
  }
}

final remoteFavorites = RemoteFavorites();
