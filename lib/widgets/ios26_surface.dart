import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/motion_artwork.dart';

/// A compact native glass surface. Keep safe-area and large content panels out
/// of this material: the platform effect is a backdrop, not native controls.
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
                      key: ValueKey(CupertinoTheme.brightnessOf(context)),
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color:
                          CupertinoTheme.brightnessOf(context) ==
                              Brightness.dark
                          ? const Color(0x24FFFFFF)
                          : const Color(0x18000000),
                      width: .5,
                    ),
                  ),
                  child: child,
                ),
              ],
            ),
          ),
  );
}
