import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musyn/services/audio/remote_favorites.dart';
import 'package:musyn/services/common_services.dart';
import 'bitchord_ui_test.dart' show UiPlayback;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'system Favorite uses local store, syncs state and rejects stale commands',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'musyn-remote-favorites-',
      );
      Hive.init(dir.path);
      await Hive.openBox('user', bytes: Uint8List(0));
      const channel = MethodChannel('test-musyn/favorites');
      final states = <Map>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            states.add(Map.from(call.arguments as Map));
            return null;
          });
      final handler = UiPlayback();
      final bridge = RemoteFavorites(channel: channel)..start(handler);
      try {
        expect(
          await bridge.handleCommand(
            const MethodCall('setFavorite', {
              'trackId': 'fixture',
              'liked': true,
            }),
          ),
          isTrue,
        );
        expect(userLikedSongsList.value.single['ytid'], 'fixture');
        expect(userLikedSongsList.value.single['title'], 'Midnight in motion');
        expect(states.last['liked'], isTrue);
        expect(
          await bridge.handleCommand(
            const MethodCall('setFavorite', {
              'trackId': 'fixture',
              'liked': true,
            }),
          ),
          isTrue,
        );
        expect(userLikedSongsList.value, hasLength(1));
        // Changes made inside the app also reach the system command immediately.
        await updateSongLikeStatus('fixture', false);
        await Future<void>.delayed(Duration.zero);
        expect(states.last['liked'], isFalse);
        await updateSongLikeStatus(
          'fixture',
          true,
          songData: {'ytid': 'fixture', 'title': 'Midnight in motion'},
        );
        await Future<void>.delayed(Duration.zero);
        expect(states.last['liked'], isTrue);
        handler.mediaItem.add(
          const MediaItem(
            id: 'new-entry',
            title: 'New song',
            extras: {'ytid': 'new-song'},
          ),
        );
        expect(
          await bridge.handleCommand(
            const MethodCall('setFavorite', {
              'trackId': 'fixture',
              'liked': false,
            }),
          ),
          isFalse,
        );
        expect(isSongAlreadyLiked('fixture'), isTrue);
        expect(
          await bridge.handleCommand(
            const MethodCall('setFavorite', {
              'trackId': 'new-song',
              'liked': true,
            }),
          ),
          isTrue,
        );
        expect(
          await bridge.handleCommand(
            const MethodCall('setFavorite', {
              'trackId': 'new-song',
              'liked': false,
            }),
          ),
          isTrue,
        );
        expect(userLikedSongsList.value.map((s) => s['ytid']), ['fixture']);
        handler.mediaItem.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(states.last['trackId'], isNull);
        expect(
          await bridge.handleCommand(
            const MethodCall('setFavorite', {
              'trackId': 'fixture',
              'liked': true,
            }),
          ),
          isFalse,
        );
      } finally {
        await bridge.dispose();
        await handler.audioPlayer.dispose();
        await Future<void>.delayed(Duration.zero);
        await Hive.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
