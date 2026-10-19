import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:musyn/models/position_data.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/formatter.dart';
import 'package:rxdart/rxdart.dart';

class PositionSlider extends StatefulWidget {
  const PositionSlider({super.key, this.qualityLabel});
  final String? qualityLabel;

  @override
  State<PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<PositionSlider> {
  bool _isDragging = false;
  double _dragValue = 0;
  Object? _currentMediaId;
  PositionData _positionData = PositionData(
    Duration.zero,
    Duration.zero,
    Duration.zero,
  );

  late final Stream<(MediaItem?, PositionData)> _sliderStream =
      Rx.combineLatest2(
        audioHandler.mediaItem.distinct((a, b) => a?.id == b?.id),
        audioHandler.positionDataStream,
        (MediaItem? item, PositionData pos) => (item, pos),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<(MediaItem?, PositionData)>(
      stream: _sliderStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final (mediaItem, positionSnapshot) = snapshot.data!;
        final mediaId = mediaItem?.id;
        final mediaChanged = mediaId != _currentMediaId;
        if (mediaChanged) {
          _currentMediaId = mediaId;
          _isDragging = false;
          _positionData = PositionData(
            Duration.zero,
            Duration.zero,
            Duration.zero,
          );
        }

        if (!mediaChanged) {
          _positionData = positionSnapshot;
        }

        final processingState =
            audioHandler.playbackState.valueOrNull?.processingState;
        final metadataDuration = mediaItem?.duration;
        final displayDuration =
            (metadataDuration != null && metadataDuration > Duration.zero)
            ? metadataDuration
            : (_positionData.duration > Duration.zero
                  ? _positionData.duration
                  : Duration.zero);
        final displayPositionData = PositionData(
          processingState == AudioProcessingState.loading
              ? Duration.zero
              : _positionData.position,
          _positionData.bufferedPosition,
          displayDuration,
        );
        final maxDuration = displayDuration.inMilliseconds > 0
            ? displayDuration.inMilliseconds.toDouble()
            : 1.0;

        final currentValue = _isDragging
            ? _dragValue
            : displayPositionData.position.inMilliseconds.toDouble();

        final isDark = isAppDarkMode(context);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: 24,
              child: CupertinoSlider(
                value: currentValue.clamp(0.0, maxDuration),
                activeColor: MusynStyle.appleRed,
                thumbColor: isDark
                    ? CupertinoColors.white
                    : CupertinoColors.black,
                onChanged: (value) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = value;
                  });
                },
                onChangeEnd: (value) {
                  audioHandler.seek(Duration(milliseconds: value.round()));
                  setState(() {
                    _isDragging = false;
                  });
                },
                max: maxDuration,
              ),
            ),
            const SizedBox(height: 4),
            _buildPositionRow(context, displayPositionData),
          ],
        );
      },
    );
  }

  Widget _buildPositionRow(BuildContext context, PositionData positionData) {
    final positionSec = _isDragging
        ? (_dragValue / 1000).round()
        : positionData.position.inSeconds;
    final durationSec = positionData.duration.inSeconds;
    final remainingSec = (durationSec - positionSec).clamp(0, durationSec);

    final positionText = positionData.duration == Duration.zero
        ? '--:--'
        : formatDuration(positionSec);
    final remainingText = positionData.duration == Duration.zero
        ? '--:--'
        : '-${formatDuration(remainingSec)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            positionText,
            style: TextStyle(
              fontSize: 11,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
          if (widget.qualityLabel != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.qualityLabel!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ),
          Text(
            remainingText,
            style: TextStyle(
              fontSize: 11,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
