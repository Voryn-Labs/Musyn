import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/widgets/player_drawer.dart';
import 'package:musyn/widgets/song_artwork.dart';

/// Musyn action sheet for selecting JioSaavn, YouTube Music, or offline audio.
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
          if (switchSource == null) {
            final current = audioHandler.mediaItem.valueOrNull;
            final currentId =
                current?.extras?['ytid']?.toString() ?? current?.id;
            if (currentId != ytid) {
              updateSheet(
                () => sourceError =
                    'The track changed. Reopen playback source for the current track.',
              );
              return;
            }
          }
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
              sourceError =
                  'Could not switch source. Choose a source to retry.';
            });
          }
        }

        return PlayerDrawer(
          title: 'Playback Source',
          subtitle: pendingSource != null
              ? 'Switching source…'
              : (sourceError ?? 'Choose where this track plays'),
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
            // Track Preview Header Card
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAppDarkMode(ctx)
                    ? const Color(0x14FFFFFF)
                    : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAppDarkMode(ctx)
                      ? const Color(0x14FFFFFF)
                      : const Color(0x0F000000),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SongArtworkWidget(
                      metadata: metadata,
                      size: 40,
                      errorWidgetIconSize: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metadata.title,
                          style: TextStyle(
                            fontFamily: MusynStyle.displayFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isAppDarkMode(ctx)
                                ? CupertinoColors.white
                                : CupertinoColors.black,
                            letterSpacing: -0.3,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          metadata.artist?.isEmpty ?? true
                              ? 'Musyn'
                              : metadata.artist!,
                          style: const TextStyle(
                            fontFamily: MusynStyle.uiFont,
                            fontSize: 13,
                            color: CupertinoColors.systemGrey,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            PlayerDrawerRow(
              title: 'JioSaavn',
              subtitle: jiosaavnAvailable
                  ? 'AAC · up to 320 kbps'
                  : 'Enable JioSaavn in Settings to use this source',
              icon: CupertinoIcons.waveform,
              iconBg: CupertinoColors.systemGreen,
              selected: currentSource == 'jiosaavn',
              enabled: jiosaavnAvailable,
              loading: pendingSource == 'jiosaavn',
              onTap: () => select('jiosaavn'),
            ),
            PlayerDrawerRow(
              title: 'YouTube Music',
              subtitle: 'AAC or Opus · quality varies by track',
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
