import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/widgets/player_drawer.dart';

/// BitChord-styled action sheet for selecting JioSaavn, YouTube Music, or Offline source.
void showAudioSourcePicker(
  BuildContext context,
  MediaItem metadata, {
  Future<String?> Function(String)? switchSource,
}) {
  final extras = metadata.extras ?? {};
  final ytid = extras['ytid']?.toString() ?? '';
  final hasDownload = hasPlayableOfflineFile(ytid);
  final resolvedSource = extras['resolvedSource'] as String?;
  final playingOffline =
      resolvedSource == 'offline' ||
      (resolvedSource == null && (extras['isOffline'] == true || hasDownload));
  final currentSource = playingOffline
      ? 'offline'
      : (resolvedSource ?? 'youtube');
  final isOffline = playingOffline;

  String? pendingSource;
  String? sourceError;

  showCupertinoModalPopup<void>(
    context: context,
    barrierColor: CupertinoColors.black.withValues(alpha: 0.50),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, updateSheet) {
        Future<void> select(String source) async {
          if (pendingSource != null) return;
          if (currentSource == source) {
            Navigator.pop(ctx);
            return;
          }
          unawaited(HapticFeedback.selectionClick());
          updateSheet(() {
            pendingSource = source;
            sourceError = null;
          });
          String? actual;
          try {
            actual = await (switchSource ?? audioHandler.switchSource)(source);
          } catch (_) {}
          if (!ctx.mounted) return;
          if (actual == source) {
            Navigator.pop(ctx);
          } else {
            updateSheet(() {
              pendingSource = null;
              sourceError = 'Could not switch source. Choose a source to retry.';
            });
          }
        }

        return PlayerDrawer(
          title: 'Playback Source',
          subtitle: pendingSource != null
              ? 'Switching source…'
              : (sourceError ?? 'Select streaming provider or offline storage'),
          trailingHeader: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: MusynStyle.uiFont,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: MusynStyle.appleRed,
              ),
            ),
          ),
          children: [
            PlayerDrawerRow(
              title: 'JioSaavn',
              badge: '320k Lossless',
              subtitle: jiosaavnEnabled.value
                  ? 'AAC · up to 320 kbps (High Fidelity)'
                  : 'Enable JioSaavn in Settings to use this source',
              icon: CupertinoIcons.waveform,
              iconBg: CupertinoColors.systemGreen,
              selected: currentSource == 'jiosaavn',
              enabled: jiosaavnEnabled.value,
              loading: pendingSource == 'jiosaavn',
              onTap: () => select('jiosaavn'),
            ),
            PlayerDrawerRow(
              title: 'YouTube Music',
              badge: '160k AAC',
              subtitle: 'AAC · Adaptive Stream',
              icon: CupertinoIcons.play_rectangle_fill,
              iconBg: const Color(0xFFFF0033),
              selected: currentSource == 'youtube',
              loading: pendingSource == 'youtube',
              onTap: () => select('youtube'),
            ),
            PlayerDrawerRow(
              title: 'Downloaded',
              badge: 'Offline',
              subtitle: hasDownload
                  ? (isOffline
                      ? 'Playing locally from this device'
                      : 'Play the downloaded copy')
                  : 'Download this track to use offline',
              icon: CupertinoIcons.arrow_down_circle_fill,
              iconBg: CupertinoColors.systemBlue,
              selected: isOffline,
              enabled: hasDownload && !isOffline,
              loading: pendingSource == 'offline',
              onTap: hasDownload ? () => select('offline') : null,
            ),
          ],
        );
      },
    ),
  );
}

bool _isPlayingOffline(Map extras) {
  final resolvedSource = extras['resolvedSource'];
  if (resolvedSource == 'offline') return true;
  if (resolvedSource == 'youtube' || resolvedSource == 'jiosaavn') return false;
  final ytid = extras['ytid']?.toString() ?? '';
  return extras['isOffline'] == true || hasPlayableOfflineFile(ytid);
}

IconData audioSourceIcon(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (_isPlayingOffline(extras)) return CupertinoIcons.device_phone_portrait;
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoIcons.waveform;
  }
  return CupertinoIcons.play_rectangle_fill;
}

Color audioSourceColor(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (_isPlayingOffline(extras)) return CupertinoColors.systemGrey;
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoColors.systemGreen;
  }
  return const Color(0xFFFF0033);
}
