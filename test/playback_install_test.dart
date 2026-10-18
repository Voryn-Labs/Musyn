import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musified/services/audio/audio_playback_coordinator.dart';

class ControlledPlayer extends AudioPlayer {
  ControlledPlayer()
    : super(handleInterruptions: false, handleAudioSessionActivation: false);
  final installed = <String>[];
  Completer<void>? loadGate;
  Completer<void>? seekGate;
  var playCount = 0;
  bool? preloaded;
  final seekPositions = <Duration?>[];
  var paused = true;
  AudioSource? source;
  @override
  bool get playing => !paused;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  AudioSource? get audioSource => source;
  @override
  Duration? get duration => const Duration(minutes: 3);
  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> sources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    preloaded = preload;
    installed.add((sources.single as UriAudioSource).uri.toString());
    await loadGate?.future;
    source = sources.single;
    return duration;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seekPositions.add(position);
    await seekGate?.future;
  }

  @override
  Future<void> play() async {
    paused = false;
    playCount++;
  }

  @override
  Future<void> pause() async {
    paused = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
  });

  Future<bool> install(
    AudioPlaybackCoordinator coordinator,
    String id, {
    required bool Function(int?) stale,
    required bool Function() shouldPlay,
    int transition = 1,
    Duration? resumeAt,
  }) => coordinator.setAudioSourceAndPlay(
    song: {'ytid': id, 'title': id},
    audioSource: AudioSource.uri(Uri.parse('https://audio.example/$id.m4a')),
    songUrl: 'https://audio.example/$id.m4a',
    isOffline: false,
    isStale: stale,
    shouldPlay: shouldPlay,
    offlineModeEnabled: () => false,
    logPlayer: (_, {extra}) {},
    onDurationKnown: (_) {},
    onPlaybackStateChanged: () {},
    ensureActuallyPlaying: (_) async {},
    onRecentlyPlayed: (_) async {},
    schedulePreload: () {},
    transitionId: transition,
    resumeAt: resumeAt,
  );

  test(
    'Pause during native loading leaves the installed track paused',
    () async {
      final player = ControlledPlayer()..loadGate = Completer<void>();
      final coordinator = AudioPlaybackCoordinator(audioPlayer: player);
      var wantsPlay = true;
      final pending = install(
        coordinator,
        'a',
        stale: (_) => false,
        shouldPlay: () => wantsPlay,
      );
      await Future<void>.delayed(Duration.zero);
      wantsPlay = false;
      player.loadGate!.complete();
      expect(await pending, isTrue);
      expect(player.playCount, 0);
      expect(player.playing, isFalse);
      expect(player.preloaded, isTrue);
      await player.dispose();
    },
  );

  test(
    'a paused source replacement loads and restores position without playing',
    () async {
      final player = ControlledPlayer();
      final coordinator = AudioPlaybackCoordinator(audioPlayer: player);
      final success = await install(
        coordinator,
        'replacement',
        stale: (_) => false,
        shouldPlay: () => false,
        resumeAt: const Duration(seconds: 75),
      );
      expect(success, isTrue);
      expect(player.preloaded, isTrue);
      expect(player.seekPositions, [const Duration(seconds: 75)]);
      expect(player.playCount, 0);
      await player.dispose();
    },
  );

  test(
    'a superseded load never starts or replaces the final selected source',
    () async {
      final player = ControlledPlayer()..loadGate = Completer<void>();
      final coordinator = AudioPlaybackCoordinator(audioPlayer: player);
      var latest = 1;
      bool stale(int? id) => id != latest;
      final first = install(
        coordinator,
        'a',
        stale: stale,
        shouldPlay: () => true,
      );
      await Future<void>.delayed(Duration.zero);
      latest = 2;
      final second = install(
        coordinator,
        'b',
        stale: stale,
        shouldPlay: () => false,
        transition: 2,
      );
      expect(player.installed.length, 1);
      player.loadGate!.complete();
      expect(await first, isFalse);
      expect(await second, isTrue);
      expect(player.installed.last, endsWith('/b.m4a'));
      expect(player.playCount, 0);
      await player.dispose();
    },
  );
}
