import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The system route picker exposes AirPlay, Bluetooth and the current output.
/// An embedded native control keeps accessibility and route state owned by iOS.
class AudioRouteButton extends StatelessWidget {
  const AudioRouteButton({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    height: 44,
    child: defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb
        ? UiKitView(
            key: ValueKey(CupertinoTheme.brightnessOf(context)),
            viewType: 'com.vorynlabs.musyn/audio_route',
            creationParams: {
              'dark': CupertinoTheme.brightnessOf(context) == Brightness.dark,
            },
            creationParamsCodec: const StandardMessageCodec(),
          )
        : Semantics(
            label: 'Audio output is managed by the system',
            child: const Icon(
              CupertinoIcons.antenna_radiowaves_left_right,
              size: 24,
            ),
          ),
  );
}
