import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/download_source_policy.dart';

void main() {
  for (final preferred in ['saavn', 'youtube']) {
    test(
      '$preferred is attempted first and fallback is announced once',
      () async {
        final attempts = <String>[];
        final notices = <String>[];
        final ok = await downloadWithSourceFallback(
          preferred: preferred,
          saavnEnabled: true,
          isCancelled: () => false,
          onFallback: notices.add,
          attempt: (source) async {
            attempts.add(source);
            return attempts.length == 2;
          },
        );
        expect(ok, isTrue);
        expect(attempts.first, preferred);
        expect(attempts.toSet().length, 2);
        expect(notices, [attempts.last]);
      },
    );
  }
  test(
    'cancellation never starts fallback or emits a fallback notice',
    () async {
      var cancelled = false;
      var attempts = 0;
      final notices = <String>[];
      expect(
        await downloadWithSourceFallback(
          preferred: 'best',
          saavnEnabled: true,
          isCancelled: () => cancelled,
          onFallback: notices.add,
          attempt: (_) async {
            attempts++;
            cancelled = true;
            return false;
          },
        ),
        isFalse,
      );
      expect(attempts, 1);
      expect(notices, isEmpty);
    },
  );
  test('a disabled source is not used and the override is announced', () async {
    final attempts = <String>[];
    final notices = <String>[];
    expect(
      await downloadWithSourceFallback(
        preferred: 'saavn',
        saavnEnabled: false,
        isCancelled: () => false,
        onFallback: notices.add,
        attempt: (source) async {
          attempts.add(source);
          return true;
        },
      ),
      isTrue,
    );
    expect(attempts, ['youtube']);
    expect(notices, ['youtube']);
  });
  test('success on preferred source never attempts fallback', () async {
    final attempts = <String>[];
    expect(
      await downloadWithSourceFallback(
        preferred: 'best',
        saavnEnabled: true,
        isCancelled: () => false,
        onFallback: (_) => fail('unexpected fallback'),
        attempt: (source) async {
          attempts.add(source);
          return true;
        },
      ),
      isTrue,
    );
    expect(attempts, ['saavn']);
  });
}
