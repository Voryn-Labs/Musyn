import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/lyrics_manager.dart';
import 'package:musyn/widgets/now_playing/lyrics/compact_lyrics_panel.dart';
import 'package:musyn/widgets/now_playing/lyrics/lyrics_theme.dart';

void main() {
  test('title cleaning removes quality labels without damaging words', () {
    for (final title in [
      'Birthday',
      'Earthquake',
      'Headquarters',
      'Shadow',
      'Childhood',
      'Ahead',
    ]) {
      expect(LyricsManager.cleanLyricsTitle('Artist', title), title);
    }
    expect(
      LyricsManager.cleanLyricsTitle(
        'Artist',
        'Artist - Birthday (Official Video) HD',
      ),
      'Birthday',
    );
  });

  testWidgets('compact lyrics tolerate stale indices when line count changes', (
    tester,
  ) async {
    for (final index in [-1, 99]) {
      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            height: 400,
            child: CompactLyricsPanel(
              lines: const [(time: Duration.zero, text: 'Only line')],
              currentIndex: index,
              lineProgress: 0,
              theme: LyricsTheme(
                isDark: true,
                accent: CupertinoColors.systemPink,
              ),
              onSeek: (_) {},
              onExpand: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Only line'), findsOneWidget);
    }
  });
}
