import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/audio/audio_completion_coordinator.dart';
import 'package:musyn/services/audio/audio_queue_state.dart';

void main() {
  test('a repeat tap on the loading song is still skipped', () {
    final completion = AudioCompletionCoordinator();

    expect(
      completion.shouldSkipPlayFromQueueAlreadyLoading(
        0,
        0,
        loadingKey: 'Y5m3FAxatX4',
        requestedKey: 'Y5m3FAxatX4',
      ),
      isTrue,
    );
  });

  test(
    'tapping a different song that lands on the loading index is honoured',
    () {
      final completion = AudioCompletionCoordinator();

      // playSingleSong replaces the queue, so the new track is also index 0.
      expect(
        completion.shouldSkipPlayFromQueueAlreadyLoading(
          0,
          0,
          loadingKey: 'Y5m3FAxatX4',
          requestedKey: 'AMfuIWDUDHg',
        ),
        isFalse,
      );
    },
  );

  test('missing song keys never skip a new load', () {
    final completion = AudioCompletionCoordinator();
    expect(completion.shouldSkipPlayFromQueueAlreadyLoading(0, 0), isFalse);
  });

  test('clearing the loading index drops the tracked song', () {
    final state = AudioQueueState()
      ..items.add({'ytid': 'abc'})
      ..markLoading(0, {'ytid': 'abc'});

    expect(state.loadingKey, 'abc');

    state.loadingIndex = -1;
    expect(state.loadingKey, isNull);
  });

  test(
    'two queue occurrences of one recording are distinct loading requests',
    () {
      final state = AudioQueueState();
      final first = {'ytid': 'abcdefghijk', 'queueEntryId': 'first'};
      final second = {'ytid': 'abcdefghijk', 'queueEntryId': 'second'};
      state.markLoading(0, first);
      expect(
        AudioCompletionCoordinator().shouldSkipPlayFromQueueAlreadyLoading(
          0,
          0,
          loadingKey: state.loadingKey,
          requestedKey: AudioQueueState.songKey(second),
        ),
        isFalse,
      );
    },
  );
}
