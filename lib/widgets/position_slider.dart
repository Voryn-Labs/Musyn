import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/models/position_data.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
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
  bool _cancelled = false;
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

        _positionData = positionSnapshot;

        final metadataDuration = mediaItem?.duration;
        final displayDuration =
            (metadataDuration != null && metadataDuration > Duration.zero)
            ? metadataDuration
            : (_positionData.duration > Duration.zero
                  ? _positionData.duration
                  : Duration.zero);
        final displayPositionData = PositionData(
          _positionData.position,
          _positionData.bufferedPosition,
          displayDuration,
        );
        final maxDuration = displayDuration.inMilliseconds > 0
            ? displayDuration.inMilliseconds.toDouble()
            : 1.0;

        final currentValue = _isDragging
            ? _dragValue
            : displayPositionData.position.inMilliseconds.toDouble();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Listener(
              onPointerDown: (_) => _cancelled = false,
              onPointerCancel: (_) {
                _cancelled = true;
                if (mounted) setState(() => _isDragging = false);
              },
              child: LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: displayDuration == Duration.zero
                      ? null
                      : (details) {
                          final fraction =
                              ((details.localPosition.dx - 22) /
                                      (box.maxWidth - 44))
                                  .clamp(0.0, 1.0);
                          unawaited(
                            audioHandler.seek(
                              Duration(
                                milliseconds: (fraction * maxDuration).round(),
                              ),
                            ),
                          );
                        },
                  child: SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: CupertinoSlider(
                      value: currentValue.clamp(0.0, maxDuration),
                      max: maxDuration,
                      activeColor: MusynStyle.appleRed,
                      onChangeStart: displayDuration == Duration.zero
                          ? null
                          : (value) {
                              unawaited(HapticFeedback.selectionClick());
                              setState(() {
                                _isDragging = true;
                                _dragValue = value;
                              });
                            },
                      onChanged: displayDuration == Duration.zero
                          ? null
                          : (value) {
                              setState(() {
                                _isDragging = true;
                                _dragValue = value;
                              });
                            },
                      onChangeEnd: displayDuration == Duration.zero
                          ? null
                          : (value) {
                              if (_cancelled) return;
                              setState(() => _isDragging = false);
                              unawaited(
                                audioHandler.seek(
                                  Duration(milliseconds: value.round()),
                                ),
                              );
                            },
                    ),
                  ),
                ),
              ),
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
