import 'package:flutter/cupertino.dart';
import 'package:musyn/widgets/now_playing/lyrics/lrc_parser.dart';
import 'package:musyn/widgets/now_playing/lyrics/lyrics_theme.dart';

/// A focused, line-timed singing view. No invented word timings or vocal mix.
class SingAlongStage extends StatelessWidget {
  const SingAlongStage({
    super.key,
    required this.lines,
    required this.index,
    required this.theme,
    required this.onSeek,
  });
  final List<LrcLine> lines;
  final int index;
  final LyricsTheme theme;
  final ValueChanged<Duration> onSeek;
  @override
  Widget build(BuildContext context) {
    final current = index.clamp(0, lines.length - 1);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (index < 0)
                  Text('WAITING FOR VOCALS', style: theme.captionStyle()),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  child: Text(
                    lines[current].text,
                    key: ValueKey(current),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: landscape ? 34 : 42,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: index < 0 ? theme.futureColor : theme.activeColor,
                    ),
                  ),
                ),
                if (current + 1 < lines.length) ...[
                  const SizedBox(height: 24),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => onSeek(lines[current + 1].time),
                    child: Text(
                      lines[current + 1].text,
                      textAlign: TextAlign.center,
                      style: theme.lineStyle(
                        isActive: false,
                        isPast: false,
                        layout: LyricsLayout.compact,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Line-synced · Original vocals',
                  textAlign: TextAlign.center,
                  style: theme.captionStyle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
