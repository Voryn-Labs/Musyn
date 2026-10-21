import 'package:just_audio/just_audio.dart';

enum StallAction { wait, resumeCurrent, advanceEnded }

/// Missing Dart callbacks are not evidence of failed native playback.
class PlaybackStallWatch {
  DateTime? _lastTick;
  DateTime? _lastProgress;
  Duration? _position;
  void reset() {
    _lastTick = null;
    _lastProgress = null;
    _position = null;
  }

  StallAction sample({
    required DateTime now,
    required Duration position,
    required bool playing,
    required ProcessingState state,
  }) {
    final gap = _lastTick == null ? Duration.zero : now.difference(_lastTick!);
    _lastTick = now;
    if (_lastProgress == null ||
        gap > const Duration(seconds: 6) ||
        gap.isNegative ||
        state == ProcessingState.loading ||
        state == ProcessingState.buffering ||
        (playing && position != _position)) {
      _position = position;
      _lastProgress = now;
      return StallAction.wait;
    }
    final quiet = now.difference(_lastProgress!);
    if ((state == ProcessingState.completed || state == ProcessingState.idle) &&
        quiet >= const Duration(seconds: 2)) {
      _lastProgress = now;
      return StallAction.advanceEnded;
    }
    if (playing &&
        state == ProcessingState.ready &&
        quiet > const Duration(seconds: 12)) {
      _lastProgress = now;
      return StallAction.resumeCurrent;
    }
    return StallAction.wait;
  }
}
