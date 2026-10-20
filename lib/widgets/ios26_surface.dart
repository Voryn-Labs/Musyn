import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/motion_artwork.dart';

/// Native UIGlassEffect only on supported, opted-in devices.
class Ios26Surface extends StatelessWidget {
  const Ios26Surface({super.key, required this.child, this.radius = 18});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ios26Design, MotionArtwork.instance]),
    builder: (context, _) =>
        !ios26Design.value || !MotionArtwork.instance.supported
        ? child
        : ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: UiKitView(
                      viewType: 'com.vorynlabs.musyn/glass',
                      creationParams: {
                        'radius': radius,
                        'dark':
                            CupertinoTheme.brightnessOf(context) ==
                            Brightness.dark,
                      },
                      creationParamsCodec: const StandardMessageCodec(),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
  );
}
