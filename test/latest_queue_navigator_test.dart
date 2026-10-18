import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/audio/latest_queue_navigator.dart';

void main() {
  test('rapid taps resolve the final queue target', () async {
    final loads = <int>[];
    final navigator = LatestQueueNavigator(
      isValid: (_) => true,
      invalidate: () {},
      load: (index) async => loads.add(index),
    );
    final done = navigator.select(1);
    unawaited(navigator.select(2));
    unawaited(navigator.select(3));
    await done;
    expect(loads, [3]);
  });

  test('a slow superseded network request cannot block a newer skip', () async {
    final slow = Completer<void>();
    final started = Completer<void>();
    final loads = <int>[];
    final navigator = LatestQueueNavigator(
      debounce: Duration.zero,
      isValid: (_) => true,
      invalidate: () {},
      load: (index) async {
        loads.add(index);
        if (index == 1) {
          started.complete();
          await slow.future;
        }
      },
    );
    final first = navigator.select(1);
    await started.future;
    await navigator.select(4).timeout(const Duration(seconds: 1));
    expect(loads, [1, 4]);
    expect(slow.isCompleted, isFalse);
    slow.complete();
    await first;
  });

  test(
    'stop cancels pending navigation without starting another track',
    () async {
      final loads = <int>[];
      final navigator = LatestQueueNavigator(
        isValid: (_) => true,
        invalidate: () {},
        load: (index) async => loads.add(index),
      );
      final done = navigator.select(2);
      navigator.cancel();
      await done;
      expect(loads, isEmpty);
    },
  );
}
