import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/audio/audio_queue_controller.dart';
import 'package:musified/services/audio/audio_queue_state.dart';

void main() {
  test(
    'missing occurrence IDs never match unrelated or unidentified songs',
    () {
      expect(
        AudioQueueController.matchesEntry({'ytid': 'a'}, {'ytid': 'b'}),
        isFalse,
      );
      expect(AudioQueueController.matchesEntry({}, {}), isFalse);
      expect(
        AudioQueueController.matchesEntry({'ytid': 'a'}, {'ytid': 'a'}),
        isTrue,
      );
      expect(
        AudioQueueController.matchesEntry(
          {'ytid': 'a', 'queueEntryId': 'one'},
          {'ytid': 'a', 'queueEntryId': 'two'},
        ),
        isFalse,
      );
    },
  );

  test(
    'unshuffle preserves additions, duplicates and the current occurrence',
    () {
      final state = AudioQueueState();
      final queue = AudioQueueController(state);
      queue.append({'ytid': 'a'});
      queue.append({'ytid': 'b'});
      state.currentIndex = 1;
      final currentId = state.currentSong!['queueEntryId'];
      queue.enableShuffle([], {});
      queue.append({'ytid': 'c'});
      queue.append({'ytid': 'a'});
      final occurrences = state.items
          .map((song) => song['queueEntryId'])
          .toSet();
      queue.disableShuffle([], {});
      expect(state.items.map((song) => song['ytid']), ['a', 'b', 'c', 'a']);
      expect(
        state.items.map((song) => song['queueEntryId']).toSet(),
        occurrences,
      );
      expect(state.currentSong!['queueEntryId'], currentId);
    },
  );

  test('shuffle safely recovers an invalid index in a nonempty queue', () {
    final state = AudioQueueState();
    final queue = AudioQueueController(state);
    queue.append({'ytid': 'a'});
    queue.append({'ytid': 'b'});
    state.currentIndex = -1;
    queue.enableShuffle([], {});
    expect(state.currentSong, isNotNull);
    state.currentIndex = 100;
    queue.disableShuffle([], {});
    expect(state.currentSong, isNotNull);
    expect(state.items.length, 2);
  });
}
