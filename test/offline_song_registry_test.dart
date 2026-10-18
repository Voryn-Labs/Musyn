import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/offline_song_registry.dart';

void main() {
  test(
    'simultaneous completions and a removal retain every later update',
    () async {
      var visible = <dynamic>[];
      var saved = <dynamic>[];
      final firstWrite = Completer<void>();
      var writes = 0;
      final registry = OfflineSongRegistry(
        read: () => visible,
        persist: (songs) async {
          if (++writes == 1) await firstWrite.future;
          saved = List.from(songs);
        },
        publish: (songs) => visible = songs,
      );
      final first = registry.upsert({'ytid': 'a'});
      final second = registry.upsert({'ytid': 'b'});
      final removal = registry.remove('a');
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      expect(visible, isEmpty);
      firstWrite.complete();
      await Future.wait([first, second, removal]);
      expect(visible, [
        {'ytid': 'b'},
      ]);
      expect(saved, visible);
    },
  );

  test(
    'failed persistence is not published and does not block later songs',
    () async {
      var visible = <dynamic>[];
      final registry = OfflineSongRegistry(
        read: () => visible,
        persist: (songs) async {
          if (songs.any((song) => song['ytid'] == 'a')) {
            throw StateError('disk full');
          }
        },
        publish: (songs) => visible = songs,
      );
      await expectLater(registry.upsert({'ytid': 'a'}), throwsStateError);
      expect(visible, isEmpty);
      await registry.upsert({'ytid': 'b'});
      expect(visible, [
        {'ytid': 'b'},
      ]);
    },
  );
}
