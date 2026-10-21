import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/audio/musyn_audio_handler.dart';
import 'package:musyn/services/settings_manager.dart';
import 'queue_recommendation_race_test.dart' show ProbePlayer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProbePlayer player;
  late MusynAudioHandler handler;
  late Future<String?> Function(Map, bool Function()?) resolve;
  final a = {
    'ytid': 'aaaaaaaaaaa',
    'title': 'Previous',
    'artist': 'Artist',
    'duration': 180,
    'source': 'youtube',
  };
  final b = {
    'ytid': 'bbbbbbbbbbb',
    'title': 'Casa',
    'artist': 'Artist',
    'duration': 180,
    'source': 'youtube',
  };
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musyn-selection-');
    Hive.init(directory.path);
    for (final name in [
      'settings',
      'user',
      'cache',
      'youtube_auth',
      'userNoBackup',
    ]) {
      await Hive.openBox(name);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    offlineMode.value = false;
    playNextSongAutomatically.value = false;
    resolve = (song, _) async {
      song['resolvedSource'] = 'youtube';
      return 'https://audio.example/${song['ytid']}.m4a';
    };
    player = ProbePlayer();
    handler = MusynAudioHandler(
      player: player,
      prepareArtwork: (_) async => null,
      resolveUrl: (song, stale) => resolve(song, stale),
    );
  });
  tearDown(() async {
    await handler.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'new selection silences old audio before publishing new artwork',
    () async {
      await handler.playSingleSong(a);
      expect(player.playing, true);
      final gate = Completer<String?>();
      resolve = (song, _) => gate.future;
      final second = handler.playSingleSong(b);
      await Future<void>.delayed(Duration.zero);
      expect(handler.mediaItem.value!.title, 'Casa');
      expect(player.playing, false);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.loading,
      );
      await handler.pause();
      await handler.play();
      expect(
        player.playing,
        false,
        reason: 'Play during lookup must not resume the previous native item',
      );
      gate.complete('https://audio.example/bbbbbbbbbbb.m4a');
      await second;
      expect(player.playing, true);
      expect(player.installed.last, contains('bbbbbbbbbbb'));
      expect(handler.mediaItem.value!.title, 'Casa');
    },
  );
  test(
    'failed queued selection remains selected, and Play retries that song',
    () async {
      await handler.playSingleSong(a);
      await handler.addToQueue(b);
      await handler.addToQueue({
        'ytid': 'ccccccccccc',
        'title': 'Different song',
      });
      resolve = (_, _) async => null;
      await handler.skipToQueueItem(1);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(handler.currentQueueIndex, 1);
      expect(handler.mediaItem.value!.title, 'Casa');
      expect(player.playing, false);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.error,
      );
      // Repeated explicit failures must not trigger the maximum-error auto-skip.
      await handler.play();
      await handler.play();
      expect(handler.currentQueueIndex, 1);
      expect(player.playing, false);
      final requested = <String>[];
      resolve = (song, _) async {
        requested.add(song['ytid']);
        return 'https://audio.example/${song['ytid']}.m4a';
      };
      await handler.play();
      expect(requested.first, 'bbbbbbbbbbb');
      expect(player.installed.last, contains('bbbbbbbbbbb'));
      expect(handler.currentQueueIndex, 1);
      expect(player.playing, true);
    },
  );
  test('late lookup cannot override a newer selected track', () async {
    await handler.playSingleSong(a);
    final gate = Completer<String?>();
    resolve = (song, _) => song['ytid'] == b['ytid']
        ? gate.future
        : Future.value('https://audio.example/${song['ytid']}.m4a');
    final slow = handler.playSingleSong(b);
    await Future<void>.delayed(Duration.zero);
    await handler.playSingleSong({'ytid': 'ccccccccccc', 'title': 'Latest'});
    gate.complete('https://audio.example/bbbbbbbbbbb.m4a');
    await slow;
    expect(handler.mediaItem.value!.title, 'Latest');
    expect(player.installed.last, contains('ccccccccccc'));
  });
}
