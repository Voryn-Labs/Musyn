import 'package:flutter/foundation.dart';
import 'package:musyn/services/audio/playback_controller.dart';

PlaybackController? audioHandlerInstance;
final audioHandlerReady = ValueNotifier<bool>(false);

PlaybackController get audioHandler {
  final handler = audioHandlerInstance;
  if (handler == null) throw StateError('audioHandler not initialized yet');
  return handler;
}

bool get isAudioHandlerInitialized => audioHandlerInstance != null;
