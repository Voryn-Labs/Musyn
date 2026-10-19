import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/utilities/async_operation_queue.dart';

void main() {
  test(
    'native mutations stay ordered while earlier work is suspended',
    () async {
      final queue = AsyncOperationQueue();
      final gate = Completer<void>();
      final events = <String>[];
      final first = queue.run(() async {
        events.add('first started');
        await gate.future;
        events.add('first ended');
      });
      final second = queue.run(() async => events.add('second'));
      await Future<void>.delayed(Duration.zero);
      expect(events, ['first started']);
      gate.complete();
      await Future.wait([first, second]);
      expect(events, ['first started', 'first ended', 'second']);
    },
  );

  test('a failed install does not prevent the next queued selection', () async {
    final queue = AsyncOperationQueue();
    final failed = queue.run<void>(() async => throw StateError('load failed'));
    final next = queue.run(() async => 'next track');
    await expectLater(failed, throwsStateError);
    expect(await next, 'next track');
  });
}
