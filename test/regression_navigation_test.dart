import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musyn/services/audio/musyn_audio_handler.dart';
import 'package:musyn/services/settings_manager.dart';

class QuietPlayer extends AudioPlayer {
  QuietPlayer()
    : super(handleInterruptions: false, handleAudioSessionActivation: false);
  @override
  Future<void> setLoopMode(LoopMode mode) async {}
  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {}
}

class RecordingHandler extends MusynAudioHandler {
  RecordingHandler() : super(player: QuietPlayer());
  final played = <String>[];
  @override
  Future<bool> playSong(
    Map song, {
    String? mediaId,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    played.add(song['ytid'].toString());
    this.mediaItem.add(
      MediaItem(
        id: song['queueEntryId'].toString(),
        title: song['title'].toString(),
        extras: {'ytid': song['ytid']},
      ),
    );
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late RecordingHandler handler;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musyn-nav-');
    Hive.init(directory.path);
    await Hive.openBox('settings');
    offlineMode.value = true;
    playNextSongAutomatically.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
    handler = RecordingHandler();
    await handler.addPlaylistToQueue([
      for (final id in ['a', 'b', 'c', 'd']) {'ytid': id, 'title': id},
    ], replace: true);
  });
  tearDown(() async {
    await handler.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'removing an earlier row rebases the pending skip to its occurrence',
    () async {
      final skip = handler.skipToQueueItem(2);
      await handler.removeFromQueue(1);
      await skip;
      expect(handler.played, ['a', 'c']);
      expect(handler.currentQueueIndex, 1);
    },
  );

  test(
    'clear during debounce cancels the skip and keeps the audible song',
    () async {
      final skip = handler.skipToQueueItem(3);
      handler.clearQueue();
      await skip;
      expect(handler.played, ['a']);
      expect(handler.queue.value.map((song) => song.extras?['ytid']), ['a']);
    },
  );
}
