import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/motion_artwork.dart';

/// Real, automatically matched artwork; keep the still cover when unavailable.
class MotionArtworkView extends StatelessWidget {
  const MotionArtworkView({
    super.key,
    required this.item,
    required this.child,
    required this.size,
  });
  final MediaItem item;
  final Widget child;
  final double size;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      MotionArtwork.instance,
      motionArtworkEnabled,
    ]),
    builder: (context, _) {
      final id = item.extras?['ytid']?.toString() ?? item.id;
      final path = MotionArtwork.instance.fileFor(id);
      if (!MotionArtwork.instance.supported ||
          !motionArtworkEnabled.value ||
          path == null ||
          MediaQuery.disableAnimationsOf(context))
        return child;
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            initialData: audioHandler.playbackState.value,
            builder: (context, state) => _NativeClip(
              key: ValueKey(path),
              path: path,
              playing: state.data?.playing ?? false,
            ),
          ),
        ),
      );
    },
  );
}

class _NativeClip extends StatefulWidget {
  const _NativeClip({super.key, required this.path, required this.playing});
  final String path;
  final bool playing;
  @override
  State<_NativeClip> createState() => _NativeClipState();
}

class _NativeClipState extends State<_NativeClip> {
  MethodChannel? _channel;
  @override
  void didUpdateWidget(covariant _NativeClip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing)
      unawaited(
        _channel
            ?.invokeMethod<void>('playing', widget.playing)
            .catchError((Object _) {}),
      );
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'com.vorynlabs.musyn/clip',
    creationParams: {'path': widget.path, 'playing': widget.playing},
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: (id) =>
        _channel = MethodChannel('com.vorynlabs.musyn/clip/$id'),
  );
}
