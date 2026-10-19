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
import 'package:musyn/widgets/sleep_timer_picker.dart';
import 'package:musyn/widgets/song_artwork.dart';
import 'package:musyn/widgets/track_action_drawer.dart';

/// Shows an Apple Music-style Cupertino action sheet with track preview.
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

  final isDark = isAppDarkMode(context);

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => TrackActionDrawer(
      title: Row(
        children: [
          SongArtworkWidget(metadata: mapToMediaItem(song), size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (artist.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    style: TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      fontSize: 13,
                      color: isDark
                          ? MusynStyle.darkSecondary
                          : CupertinoColors.systemGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (isAudioHandlerInitialized &&
            audioHandler.currentPlayingYtid.value == ytid)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showSleepTimerPicker(context);
            },
            child: const Row(
              children: [
                Icon(CupertinoIcons.moon_zzz, size: 20),
                SizedBox(width: 10),
                Text('Sleep timer'),
              ],
            ),
          ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            audioHandler.playNext(song);
            showToast(context, 'Playing next');
          },
          child: const Row(
            children: [
              Icon(CupertinoIcons.play_rectangle, size: 20),
              SizedBox(width: 10),
              Text('Play Next'),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            audioHandler.addToQueue(song);
            showToast(context, 'Added to queue');
          },
          child: const Row(
            children: [
              Icon(CupertinoIcons.text_badge_plus, size: 20),
              SizedBox(width: 10),
              Text('Add to Queue'),
            ],
          ),
        ),
        if (!offlineMode.value)
          CupertinoActionSheetAction(
            onPressed: () async {
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
            child: Row(
              children: [
                Icon(
                  isLiked
                      ? CupertinoIcons.heart_slash_fill
                      : CupertinoIcons.heart_fill,
                  size: 20,
                  color: isLiked
                      ? CupertinoColors.systemRed
                      : MusynStyle.appleRed,
                ),
                const SizedBox(width: 10),
                Text(isLiked ? 'Remove from Favorites' : 'Favorite'),
              ],
            ),
          ),
        if (!offlineMode.value)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showAddToPlaylistDialog(context, song: song);
            },
            child: const Row(
              children: [
                Icon(CupertinoIcons.plus_circle, size: 20),
                SizedBox(width: 10),
                Text('Add to a Playlist...'),
              ],
            ),
          ),
        CupertinoActionSheetAction(
          onPressed: () async {
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
                if (context.mounted)
                  showToast(
                    context,
                    success
                        ? 'Downloaded to device'
                        : 'Download failed. Try again.',
                  );
              });
            }
          },
          child: Row(
            children: [
              Icon(
                isOffline
                    ? CupertinoIcons.trash
                    : CupertinoIcons.arrow_down_circle,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(isOffline ? 'Remove Download' : 'Download to Device'),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(ctx);
            showSongInfoDialog(context, song);
          },
          child: const Row(
            children: [
              Icon(CupertinoIcons.info_circle, size: 20),
              SizedBox(width: 10),
              Text('Track Details'),
            ],
          ),
        ),
        if (canRemove && onRemove != null)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              onRemove();
            },
            child: const Row(
              children: [
                Icon(
                  CupertinoIcons.delete,
                  size: 20,
                  color: CupertinoColors.destructiveRed,
                ),
                SizedBox(width: 10),
                Text('Remove'),
              ],
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Done'),
      ),
    ),
  );
}
