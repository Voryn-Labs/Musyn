import 'dart:math' as math;
import 'package:flutter/cupertino.dart';

/// A quiet moving sleeve while audio plays. Pause holds its current pose;
/// Reduce Motion presents the original, stationary artwork.
class PlayingArtworkMotion extends StatefulWidget {
  const PlayingArtworkMotion({
    super.key,
    required this.playing,
    required this.child,
  });
  final bool playing;
  final Widget child;
  @override
  State<PlayingArtworkMotion> createState() => _PlayingArtworkMotionState();
}

class _PlayingArtworkMotionState extends State<PlayingArtworkMotion>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  bool _reduced = false;
  void _sync() {
    if (widget.playing && !_reduced) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop(canceled: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant PlayingArtworkMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: widget.child,
    builder: (context, child) {
      final phase = _motion.value * math.pi * 2;
      return Transform(
        key: const ValueKey('playing-artwork-motion'),
        alignment: Alignment.center,
        transform: _reduced
            ? Matrix4.identity()
            : (Matrix4.identity()
                ..translateByDouble(0, math.sin(phase) * 3, 0, 1)
                ..rotateZ(math.sin(phase) * .024)
                ..scaleByDouble(1.015, 1.015, 1, 1)),
        child: child,
      );
    },
  );
}
