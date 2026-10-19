import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/audio/audio_completion_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a failed asynchronous completion releases gates without an unhandled error',
    () async {
      final completion = AudioCompletionCoordinator()
        ..handlerLoadStarted = true;
      completion.handleProcessingCompleted(
        ProcessingCompletedContext(
          loadInProgress: false,
          sourceSwitchInFlight: false,
          sleepTimerEndOfSong: false,
          sleepTimerExpired: false,
          onSleepTimerEndOfSong: () {},
          logPlayer: (_) {},
          onCompleteTrack: () async =>
              throw StateError('stream changed during completion'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(completion.eventPending, isFalse);
      expect(completion.handlerLoadStarted, isFalse);
    },
  );
  testWidgets(
    'Pause during delayed completion retry prevents the second skip',
    (tester) async {
      var wantsPlay = true;
      var skips = 0;
      final pending = AudioCompletionCoordinator().completeSong(
        SongCompletionContext(
          addCurrentToHistory: () async {},
          repeatOne: false,
          playAgain: () async {},
          skipToNext: () async {
            skips++;
          },
          currentQueueIndex: () => 0,
          stopPlayback: () async {},
          audioIsPlaying: () => false,
          hasAnotherTrack: () => true,
          mayRetry: () => wantsPlay,
        ),
      );
      await tester.pump();
      expect(skips, 1);
      wantsPlay = false;
      await tester.pump(const Duration(milliseconds: 600));
      await pending;
      expect(skips, 1);
    },
  );
}
