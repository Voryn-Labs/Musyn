import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musyn/services/audio/musyn_audio_handler.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/library_state.dart';
import 'playback_install_test.dart' show ControlledPlayer;

class ProbePlayer extends ControlledPlayer {
  @override
  Future<void> setLoopMode(LoopMode value) async {}
  @override
  Future<void> setShuffleModeEnabled(bool value) async {}
  @override
  Future<void> setVolume(double value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final action in ['clearQueue', 'switchSource']) {
    test(
      '$action invalidates an already-running end-of-queue recommendation',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'musyn-audit-queue-',
        );
        Hive.init(directory.path);
        for (final box in [
          'settings',
          'user',
          'cache',
          'youtube_auth',
          'userNoBackup',
        ]) {
          await Hive.openBox(box, bytes: Uint8List(0));
        }
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.ryanheise.audio_session'),
              (_) async => null,
            );
        final player = ProbePlayer()..paused = false;
        final handler = MusynAudioHandler(
          player: player,
          prepareArtwork: (_) async => null,
        );
        try {
          offlineMode.value = false;
          playNextSongAutomatically.value = true;
          await handler.addToQueue({
            'ytid': 'abcdefghijk',
            'title': 'Original track',
            'artist': 'Artist',
            'duration': 180,
          });
          final offline = File('${directory.path}/recommendation.m4a');
          await offline.writeAsBytes(List.filled(60000, 1));
          userOfflineSongs.value = [
            {
              'ytid': 'abcdefghijk',
              'title': 'Original track',
              'artist': 'Artist',
              'audioPath': offline.path,
            },
            {
              'ytid': 'lmnopqrstuv',
              'title': 'Stale recommendation',
              'artist': 'Artist',
              'audioPath': offline.path,
            },
          ];
          final entered = Completer<void>();
          final response = Completer<http.Response>();
          await http.runWithClient(
            () async {
              final skipping = handler.skipToNext();
              await entered.future.timeout(const Duration(seconds: 2));
              if (action == 'clearQueue') {
                handler.clearQueue();
              } else {
                expect(await handler.switchSource('offline'), 'offline');
              }
              response.complete(
                http.Response(
                  jsonEncode({
                    'playlistPanelVideoRenderer': {
                      'videoId': 'lmnopqrstuv',
                      'title': {
                        'runs': [
                          {'text': 'Stale recommendation'},
                        ],
                      },
                      'longBylineText': {
                        'runs': [
                          {'text': 'Artist'},
                        ],
                      },
                    },
                  }),
                  200,
                ),
              );
              await skipping.timeout(const Duration(seconds: 5));
              expect(
                handler.queue.value
                    .map((item) => item.extras?['ytid'])
                    .toList(),
                ['abcdefghijk'],
              );
            },
            () => MockClient((request) {
              if (!entered.isCompleted) entered.complete();
              return response.future;
            }),
          );
        } finally {
          await handler.dispose();
          await Hive.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
  test(
    'a delayed cover for the previous song cannot replace the selected cover',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'musyn-artwork-race-',
      );
      Hive.init(directory.path);
      for (final box in [
        'settings',
        'user',
        'cache',
        'youtube_auth',
        'userNoBackup',
      ]) {
        await Hive.openBox(box, bytes: Uint8List(0));
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.audio_session'),
            (_) async => null,
          );
      final covers = <String, Completer<Uri?>>{};
      final handler = MusynAudioHandler(
        player: ProbePlayer(),
        prepareArtwork: (uri) =>
            covers.putIfAbsent(uri.toString(), Completer<Uri?>.new).future,
      );
      try {
        playNextSongAutomatically.value = false;
        offlineMode.value = true;
        final audio = File('${directory.path}/song.m4a');
        await audio.writeAsBytes(List.filled(60000, 1));
        final songs = [
          {
            'ytid': 'abcdefghijk',
            'title': 'First song',
            'artist': 'Artist',
            'duration': 180,
            'image': 'https://covers.example/first.jpg',
            'audioPath': audio.path,
          },
          {
            'ytid': 'lmnopqrstuv',
            'title': 'Second song',
            'artist': 'Artist',
            'duration': 180,
            'image': 'https://covers.example/second.jpg',
            'audioPath': audio.path,
          },
        ];
        userOfflineSongs.value = songs;
        for (final song in songs) {
          await handler.addToQueue(song);
        }
        await handler.skipToQueueItem(1);
        expect(handler.mediaItem.valueOrNull?.title, 'Second song');
        covers['https://covers.example/first.jpg']!.complete(
          Uri.file('${directory.path}/first.png'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          handler.mediaItem.valueOrNull?.artUri.toString(),
          'https://covers.example/second.jpg',
        );
        covers['https://covers.example/second.jpg']!.complete(
          Uri.file('${directory.path}/second.png'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          handler.mediaItem.valueOrNull?.artUri,
          Uri.file('${directory.path}/second.png'),
        );
        expect(handler.mediaItem.valueOrNull?.title, 'Second song');
      } finally {
        await handler.dispose();
        userOfflineSongs.value = [];
        offlineMode.value = false;
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
