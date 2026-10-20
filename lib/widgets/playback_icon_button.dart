import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/extensions/l10n.dart';
import 'package:musyn/services/audio/audio_runtime.dart';

Widget buildPlaybackIconButton(
  double iconSize,
  Color iconColor,
  Color backgroundColor, {
  EdgeInsets? padding,
}) {
  // `audioHandler` throws until AudioService finishes initializing (see
  // main.dart). Callers of this widget are usually gated behind that check
  // already (e.g. the mini player only appears once a media item exists),
  // but guard here too so this can never crash into the red error screen if
  // it's ever reached a beat early - show the same loading spinner used
  // below instead.
  if (!isAudioHandlerInitialized) {
    return CupertinoButton(
      onPressed: null,
      color: backgroundColor,
      padding: padding ?? EdgeInsets.all(iconSize * 0.35),
      minimumSize: const Size(40, 40),
      borderRadius: BorderRadius.circular(100),
      child: CupertinoActivityIndicator(
        radius: iconSize * 0.5,
        color: iconColor,
      ),
    );
  }

  return StreamBuilder<PlaybackState>(
    initialData: audioHandler.playbackState.value,
    stream: audioHandler.playbackState.distinct((previous, current) {
      // Only rebuild if relevant state changes
      return previous.playing == current.playing &&
          previous.processingState == current.processingState;
    }),
    builder: (context, snapshot) {
      final playbackState = snapshot.data;
      final processingState = playbackState?.processingState;
      final isPlaying = playbackState?.playing ?? false;

      Widget iconWidget;
      VoidCallback? onPressed;
      String? semanticLabel;

      final isBufferingOrLoading =
          processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering;

      if (isPlaying) {
        iconWidget = Icon(
          CupertinoIcons.pause_fill,
          color: iconColor,
          size: iconSize,
        );
        onPressed = () {
          HapticFeedback.mediumImpact();
          audioHandler.pause();
        };
        semanticLabel = context.l10n.pause;
      } else if (isBufferingOrLoading) {
        iconWidget = SizedBox(
          width: iconSize,
          height: iconSize,
          child: CupertinoActivityIndicator(
            radius: iconSize * 0.5,
            color: iconColor,
          ),
        );
        onPressed = audioHandler.stop;
        semanticLabel = 'Cancel loading';
      } else if (processingState == AudioProcessingState.completed) {
        iconWidget = Icon(
          CupertinoIcons.arrow_counterclockwise,
          color: iconColor,
          size: iconSize,
        );
        onPressed = () {
          HapticFeedback.mediumImpact();
          audioHandler.playAgain();
        };
        semanticLabel = context.l10n.replay;
      } else {
        iconWidget = Icon(
          CupertinoIcons.play_fill,
          color: iconColor,
          size: iconSize,
        );
        onPressed = () {
          HapticFeedback.mediumImpact();
          audioHandler.play();
        };
        semanticLabel = context.l10n.play;
      }

      return CupertinoButton(
        onPressed: onPressed,
        color: backgroundColor,
        padding: padding ?? EdgeInsets.all(iconSize * 0.35),
        minimumSize: const Size(40, 40),
        borderRadius: BorderRadius.circular(100),
        child: Semantics(
          label: semanticLabel,
          button: true,
          child: ExcludeSemantics(
            child: SizedBox(
              width: iconSize,
              height: iconSize,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 140),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .9, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(semanticLabel),
                  child: iconWidget,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class PlaybackIconButton extends StatelessWidget {
  const PlaybackIconButton({
    super.key,
    required this.iconSize,
    required this.iconColor,
    required this.backgroundColor,
    this.padding,
  });

  final double iconSize;
  final Color iconColor;
  final Color backgroundColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return buildPlaybackIconButton(
      iconSize,
      iconColor,
      backgroundColor,
      padding: padding,
    );
  }
}
