import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/audio/audio_completion_coordinator.dart';

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
}
