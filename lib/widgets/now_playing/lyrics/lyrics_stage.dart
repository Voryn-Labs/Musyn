import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/widgets/now_playing/lyrics/lrc_parser.dart';
import 'package:musyn/widgets/now_playing/lyrics/lyrics_theme.dart';

/// Full-screen synced lyrics with center-aligned active line,
/// pink accent highlight, auto-scrolling, and smooth transitions.
class LyricsStage extends StatelessWidget {
  const LyricsStage({
    super.key,
    required this.lines,
    required this.currentIndex,
    required this.theme,
    required this.scrollController,
    required this.lineKeys,
    required this.onUserScroll,
    required this.onSeek,
    this.lineProgress = 0,
  });

  final List<LrcLine> lines;
  final int currentIndex;
  final LyricsTheme theme;
  final ScrollController scrollController;
  final List<GlobalKey> lineKeys;
  final VoidCallback onUserScroll;
  final ValueChanged<Duration> onSeek;
  final double lineProgress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification) {
              onUserScroll();
            }
            return false;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height;
              return ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.only(
                  top: viewportHeight * 0.45,
                  bottom: viewportHeight * 0.45,
                  left: 28,
                  right: 28,
                ),
                physics: const BouncingScrollPhysics(),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final isCurrent = index == currentIndex;
                  final isPast = index < currentIndex;
                  final key = index < lineKeys.length ? lineKeys[index] : null;

                  return _StageLine(
                    key: key,
                    line: line,
                    isCurrent: isCurrent,
                    isPast: isPast,
                    theme: theme,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSeek(line.time);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StageLine extends StatelessWidget {
  const _StageLine({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.isPast,
    required this.theme,
    required this.onTap,
  });

  final LrcLine line;
  final bool isCurrent;
  final bool isPast;
  final LyricsTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedPadding(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: AnimatedScale(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          scale: isCurrent ? 1.0 : 0.94,
          child: AnimatedDefaultTextStyle(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            style: theme.lineStyle(
              isActive: isCurrent,
              isPast: isPast,
              layout: LyricsLayout.stage,
            ),
            child: Text(line.text, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
