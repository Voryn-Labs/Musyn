import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';

/// A root player sheet whose transition can be driven continuously by a finger.
/// It accepts a builder to keep navigation independent of playback UI/services.
class PlayerSheetRoute extends PageRoute<void> {
  PlayerSheetRoute({
    required this.builder,
    this.interactive = false,
    this.reduceMotion = false,
    this.initialProgress = 0,
  }) : super(allowSnapshotting: false);
  final WidgetBuilder builder;
  final bool interactive;
  final bool reduceMotion;
  final double initialProgress;
  @override
  bool get opaque => false;
  @override
  bool get barrierDismissible => false;
  @override
  Color? get barrierColor => const Color(0x66000000);
  @override
  String? get barrierLabel => 'Now playing';
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 360);
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 280);
  @override
  bool get maintainState => true;

  @override
  TickerFuture didPush() {
    final ticker = super.didPush();
    if (interactive) controller!.stop();
    if (!interactive && initialProgress > 0) {
      controller!.value = initialProgress;
      return controller!.animateTo(
        1,
        duration: transitionDuration,
        curve: Curves.easeOutCubic,
      );
    }
    return ticker;
  }

  void dragBy(double delta, double height) {
    controller!.stop();
    controller!.value = (controller!.value - delta / height).clamp(0.0, 1.0);
  }

  void settle(
    double velocity, {
    bool opening = false,
    bool reduceMotion = false,
  }) {
    final show = opening
        ? velocity < -350 || (velocity < 350 && controller!.value > .15)
        : !(velocity > 350 || (velocity > -350 && controller!.value < .78));
    if (!show) {
      navigator?.pop();
      return;
    }
    if (reduceMotion) {
      controller!.value = 1;
      return;
    }
    controller!
        .animateWith(
          SpringSimulation(
            SpringDescription.withDampingRatio(
              mass: 1,
              stiffness: 320,
              ratio: .85,
            ),
            controller!.value,
            1,
            -velocity / 900,
          ),
        )
        .then((_) {
          // A spring finishes within tolerance, not necessarily at exactly 1.
          // Complete the route transition so navigator state and semantics settle.
          if (isActive) controller?.value = 1;
        });
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => HeroMode(
    // The sheet owns its gesture transition. Hero flights can lose their
    // destination when track artwork changes or the phone rotates mid-flight.
    enabled: false,
    child: builder(context),
  );
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SlideTransition(
    position: Tween(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(animation),
    child: ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(24 * (1 - animation.value)),
      ),
      child: child,
    ),
  );
}
