import 'dart:async';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_browse_catalog.dart';
import 'package:musyn/services/audio/playback_controller.dart';
import 'package:musyn/services/library_state.dart';
import 'package:musyn/utilities/mediaitem.dart';

/// CarPlay uses the same browse catalog, queue transactions and player as iPhone.
/// No searches, provider logins or Sing preparation run from this bridge.
class CarPlayBridge {
  CarPlayBridge({
    this.channel = const MethodChannel('com.vorynlabs.musyn/carplay'),
  });
  final MethodChannel channel;
  PlaybackController? _handler;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Timer? _timer;
  bool _connected = false;
  int _connectionEpoch = 0;
  int _epoch = 0;
  Map<String, Set<String>> _visible = {};
  static const categories = <String, String>{
    AudioBrowseCatalog.rootQueue: 'Queue',
    AudioBrowseCatalog.rootOffline: 'Downloads',
    AudioBrowseCatalog.rootLiked: 'Favorites',
    AudioBrowseCatalog.rootRecent: 'Recently Played',
  };

  void start(PlaybackController handler) {
    _handler = handler;
    channel.setMethodCallHandler(handle);
    final connection = _connectionEpoch;
    // Covers the car connecting before Dart finished opening the library.
    unawaited(
      channel
          .invokeMethod<bool>('ready')
          .then((connected) {
            if (_handler == handler && connection == _connectionEpoch) {
              _setConnected(connected == true);
            }
          })
          .catchError((Object _) {}),
    );
  }

  void _setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    ++_epoch;
    if (connected) {
      final handler = _handler;
      if (handler == null) return;
      _subscriptions.add(handler.queue.listen((_) => _schedule()));
      _subscriptions.add(handler.mediaItem.listen((_) => _schedule()));
      _subscriptions.add(handler.playbackState.listen((_) => _schedule()));
      userLikedSongsList.addListener(_schedule);
      userOfflineSongs.addListener(_schedule);
      userRecentlyPlayed.addListener(_schedule);
      _schedule();
    } else {
      _timer?.cancel();
      _timer = null;
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
      _subscriptions.clear();
      userLikedSongsList.removeListener(_schedule);
      userOfflineSongs.removeListener(_schedule);
      userRecentlyPlayed.removeListener(_schedule);
      _visible = {};
    }
  }

  void _schedule() {
    if (!_connected || _timer != null) return;
    _timer = Timer(const Duration(milliseconds: 100), () {
      _timer = null;
      unawaited(_sync().catchError((Object _) {}));
    });
  }

  Future<void> _sync() async {
    final handler = _handler;
    if (handler == null || !_connected) return;
    final epoch = ++_epoch;
    final sections = <Map<String, dynamic>>[];
    final visible = <String, Set<String>>{};
    for (final category in categories.entries) {
      if (epoch != _epoch || !_connected || _handler != handler) return;
      final items = (await handler.getChildren(
        category.key,
      )).take(100).toList();
      visible[category.key] = items.map((item) => item.id).toSet();
      sections.add({
        'id': category.key,
        'title': category.value,
        'items': items
            .map(
              (item) => {
                'id': item.id,
                'title': item.title,
                'artist': item.artist ?? '',
                'playing':
                    item.id == handler.mediaItem.valueOrNull?.id &&
                    handler.playbackState.value.playing,
              },
            )
            .toList(),
      });
    }
    if (epoch != _epoch || !_connected || _handler != handler) return;
    _visible = visible;
    await channel.invokeMethod<void>('setState', {
      'epoch': epoch,
      'sections': sections,
    });
  }

  Future<bool> handle(MethodCall call) async {
    if (call.method == 'connection') {
      ++_connectionEpoch;
      _setConnected(call.arguments == true);
      return true;
    }
    if (call.method != 'play' || call.arguments is! Map) return false;
    final args = call.arguments as Map;
    final category = args['category'];
    final id = args['id'];
    final handler = _handler;
    if (!_connected ||
        handler == null ||
        id is! String ||
        category is! String ||
        _visible[category]?.contains(id) != true)
      return false;
    // Validate against the live catalog as well: an old car row must not play
    // a different entry after a queue reorder or deletion.
    final items = await handler.getChildren(category);
    final index = items.indexWhere((item) => item.id == id);
    if (!_connected || index < 0 || _handler != handler) return false;
    if (category == AudioBrowseCatalog.rootQueue) {
      await handler.skipToSong(index);
    } else {
      await handler.playPlaylistSong(
        playlist: {
          'title': categories[category],
          'source': 'carplay',
          'list': items.map(mediaItemToMap).toList(),
        },
        songIndex: index,
      );
    }
    return true;
  }

  Future<void> dispose() async {
    ++_connectionEpoch;
    _setConnected(false);
    _handler = null;
    ++_epoch;
    _timer?.cancel();
    _timer = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    userLikedSongsList.removeListener(_schedule);
    userOfflineSongs.removeListener(_schedule);
    userRecentlyPlayed.removeListener(_schedule);
    channel.setMethodCallHandler(null);
  }
}

final carPlay = CarPlayBridge();
