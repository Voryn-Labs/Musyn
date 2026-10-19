import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
            _AppleMusicScrubber(
              value: currentValue.clamp(0.0, maxDuration),
              max: maxDuration,
              isDragging: _isDragging,
              isDark: isDark,
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
            ),
            const SizedBox(height: 2),
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

class _AppleMusicScrubber extends StatelessWidget {
  const _AppleMusicScrubber({
    required this.value,
    required this.max,
    required this.isDragging,
    required this.isDark,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double max;
  final bool isDragging;
  final bool isDark;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final progress = (max > 0 ? (value / max) : 0.0).clamp(0.0, 1.0);
        final thumbDiameter = isDragging ? 18.0 : 13.0;
        final trackHeight = isDragging ? 5.0 : 4.0;
        final activeWidth = totalWidth * progress;

        void handleTouch(Offset localPosition) {
          final ratio = (localPosition.dx / totalWidth).clamp(0.0, 1.0);
          onChanged(ratio * max);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            unawaited(HapticFeedback.selectionClick());
            handleTouch(details.localPosition);
          },
          onHorizontalDragUpdate: (details) {
            handleTouch(details.localPosition);
          },
          onHorizontalDragEnd: (_) {
            onChangeEnd(value);
          },
          onHorizontalDragCancel: () {
            onChangeEnd(value);
          },
          onTapDown: (details) {
            unawaited(HapticFeedback.selectionClick());
            handleTouch(details.localPosition);
          },
          onTapUp: (details) {
            handleTouch(details.localPosition);
            onChangeEnd(value);
          },
          child: SizedBox(
            width: totalWidth,
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                // Inactive background track
                Center(
                  child: Container(
                    height: trackHeight,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x38FFFFFF)
                          : const Color(0x26000000),
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                ),
                // Active progress track
                Positioned(
                  left: 0,
                  top: (28 - trackHeight) / 2,
                  child: Container(
                    height: trackHeight,
                    width: activeWidth,
                    decoration: BoxDecoration(
                      color: MusynStyle.appleRed,
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                ),
                // Native Apple Music sleek white scrubber thumb
                Positioned(
                  left: (activeWidth - (thumbDiameter / 2))
                      .clamp(0.0, totalWidth - thumbDiameter),
                  top: (28 - thumbDiameter) / 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: thumbDiameter,
                    height: thumbDiameter,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: CupertinoColors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x44000000),
                          blurRadius: 4,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
