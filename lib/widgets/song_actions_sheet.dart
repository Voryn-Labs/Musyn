import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/mediaitem.dart';
import 'package:musyn/utilities/playlist_dialogs.dart';
import 'package:musyn/utilities/song_info_dialog.dart';
import 'package:musyn/widgets/download_picker_sheet.dart';
import 'package:musyn/widgets/player_drawer.dart';
import 'package:musyn/widgets/sleep_timer_picker.dart';
import 'package:musyn/widgets/song_artwork.dart';

/// Shows a BitChord-styled drawer with track preview and rounded action cards.
void showSongActionsSheet(
  BuildContext context, {
  required Map song,
  bool canRemove = false,
  VoidCallback? onRemove,
  bool isRecent = false,
}) {
  final ytid = song['ytid']?.toString() ?? '';
  final title = song['title']?.toString() ?? 'Track Options';
  final artist = song['artist']?.toString() ?? '';
  final isLiked = isSongAlreadyLiked(ytid);
  final isOffline = isSongAlreadyOffline(ytid);

  showCupertinoModalPopup<void>(
    context: context,
    barrierColor: CupertinoColors.black.withValues(alpha: 0.50),
    builder: (ctx) {
      final isDark = isAppDarkMode(ctx);
      final mediaItem = mapToMediaItem(song);

      return PlayerDrawer(
        title: 'Track Options',
        subtitle: artist.isNotEmpty ? '$title · $artist' : title,
        trailingHeader: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Done',
            style: TextStyle(
              fontFamily: MusynStyle.uiFont,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MusynStyle.appleRed,
            ),
          ),
        ),
        children: [
          // Track Preview Card
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SongArtworkWidget(
                    metadata: mediaItem,
                    size: 52,
                    errorWidgetIconSize: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: MusynStyle.displayFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist.isEmpty ? 'Musyn' : artist,
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

          if (isAudioHandlerInitialized &&
              audioHandler.currentPlayingYtid.value == ytid)
            PlayerDrawerRow(
              title: 'Sleep timer',
              subtitle: 'Set a countdown to pause playback',
              icon: CupertinoIcons.moon_zzz_fill,
              iconBg: CupertinoColors.systemOrange,
              onTap: () {
                Navigator.pop(ctx);
                showSleepTimerPicker(context);
              },
            ),

          PlayerDrawerRow(
            title: 'Play Next',
            subtitle: 'Insert directly after current song',
            icon: CupertinoIcons.play_rectangle_fill,
            iconBg: CupertinoColors.systemIndigo,
            onTap: () {
              Navigator.pop(ctx);
              audioHandler.playNext(song);
              showToast(context, 'Playing next');
            },
          ),

          PlayerDrawerRow(
            title: 'Add to Queue',
            subtitle: 'Append to the end of Playing Next queue',
            icon: CupertinoIcons.text_badge_plus,
            iconBg: CupertinoColors.systemTeal,
            onTap: () {
              Navigator.pop(ctx);
              audioHandler.addToQueue(song);
              showToast(context, 'Added to queue');
            },
          ),

          if (!offlineMode.value)
            PlayerDrawerRow(
              title: isLiked ? 'Remove from Favorites' : 'Add to Favorites',
              subtitle: isLiked
                  ? 'Remove from your liked library'
                  : 'Save to your liked songs',
              badge: isLiked ? 'Liked' : null,
              icon: isLiked
                  ? CupertinoIcons.heart_slash_fill
                  : CupertinoIcons.heart_fill,
              iconBg: isLiked
                  ? CupertinoColors.systemRed
                  : MusynStyle.appleRed,
              onTap: () async {
                Navigator.pop(ctx);
                unawaited(HapticFeedback.mediumImpact());
                final nextLiked = !isLiked;
                await updateSongLikeStatus(ytid, nextLiked, songData: song);
                if (context.mounted) {
                  showToast(
                    context,
                    nextLiked
                        ? 'Added to Liked Songs'
                        : 'Removed from Liked Songs',
                  );
                }
              },
            ),

          if (!offlineMode.value)
            PlayerDrawerRow(
              title: 'Add to Playlist',
              subtitle: 'Save track into a custom playlist',
              icon: CupertinoIcons.plus_circle_fill,
              iconBg: CupertinoColors.systemPurple,
              onTap: () {
                Navigator.pop(ctx);
                showAddToPlaylistDialog(context, song: song);
              },
            ),

          PlayerDrawerRow(
            title: isOffline ? 'Remove Download' : 'Download to Device',
            subtitle: isOffline
                ? 'Delete offline copy from local storage'
                : 'Download high quality AAC for offline listening',
            badge: isOffline ? 'Saved' : null,
            icon: isOffline
                ? CupertinoIcons.trash_fill
                : CupertinoIcons.arrow_down_circle_fill,
            iconBg: isOffline
                ? CupertinoColors.systemRed
                : CupertinoColors.systemGreen,
            onTap: () async {
              Navigator.pop(ctx);
              if (isOffline) {
                await removeSongFromOffline(ytid);
                if (context.mounted) showToast(context, 'Download removed');
              } else {
                await showDownloadPicker(context, song, (source, quality) async {
                  final success = await makeSongOffline(
                    song,
                    source: source,
                    quality: quality,
                  );
                  if (context.mounted) {
                    showToast(
                      context,
                      success
                          ? 'Downloaded to device'
                          : 'Download failed. Try again.',
                    );
                  }
                });
              }
            },
          ),

          PlayerDrawerRow(
            title: 'Track Details',
            subtitle: 'Inspect audio format, bitrate, and source',
            icon: CupertinoIcons.info_circle_fill,
            iconBg: CupertinoColors.systemBlue,
            onTap: () {
              Navigator.pop(ctx);
              showSongInfoDialog(context, song);
            },
          ),

          if (canRemove && onRemove != null)
            PlayerDrawerRow(
              title: 'Remove',
              subtitle: 'Remove from this playlist or history',
              icon: CupertinoIcons.delete_solid,
              iconBg: CupertinoColors.destructiveRed,
              onTap: () {
                Navigator.pop(ctx);
                onRemove();
              },
            ),
        ],
      );
    },
  );
}
