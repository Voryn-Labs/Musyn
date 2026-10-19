import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/widgets/playing_artwork_motion.dart';

void main() {
  testWidgets('artwork moves while playing and freezes when paused', (
    tester,
  ) async {
    Widget app(bool playing, {bool reduced = false}) => CupertinoApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: PlayingArtworkMotion(
          playing: playing,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    List<double> matrix() => List.of(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('playing-artwork-motion')),
          )
          .transform
          .storage,
    );
    await tester.pumpWidget(app(true));
    final start = matrix();
    await tester.pump(const Duration(seconds: 2));
    expect(matrix(), isNot(start));
    await tester.pumpWidget(app(false));
    final paused = matrix();
    await tester.pump(const Duration(seconds: 2));
    expect(matrix(), paused);
    await tester.pumpWidget(app(true, reduced: true));
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('playing-artwork-motion')),
          )
          .transform
          .isIdentity(),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
