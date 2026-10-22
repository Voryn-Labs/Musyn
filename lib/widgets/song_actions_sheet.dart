import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/mediaitem.dart';
import 'package:musyn/utilities/playlist_dialogs.dart';
import 'package:musyn/utilities/song_info_dialog.dart';
import 'package:musyn/widgets/download_picker_sheet.dart';
import 'package:musyn/widgets/now_playing/source_picker_sheet.dart';
import 'package:musyn/widgets/sleep_timer_picker.dart';
import 'package:musyn/widgets/song_artwork.dart';
import 'package:musyn/widgets/track_organization_sheet.dart';

/// Native grouped actions share the player's typography and neutral surfaces.
void showSongActionsSheet(
  BuildContext context, {
  required Map song,
  bool canRemove = false,
  VoidCallback? onRemove,
  bool isRecent = false,
}) {
  final id = song['ytid']?.toString() ?? '';
  final liked = isSongAlreadyLiked(id);
  final offline = hasPlayableOfflineFile(id);
  final current =
      isAudioHandlerInitialized && audioHandler.currentPlayingYtid.value == id;
  final metadata = mapToMediaItem(song);
  showCupertinoModalPopup<void>(
    context: context,
    builder: (sheet) {
      Widget action(
        IconData icon,
        String title,
        VoidCallback callback, {
        bool destructive = false,
      }) => CupertinoActionSheetAction(
        isDestructiveAction: destructive,
        onPressed: () {
          Navigator.pop(sheet);
          callback();
        },
        child: Row(
          children: [
            Icon(icon, size: 21),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
          ],
        ),
      );
      return CupertinoActionSheet(
        title: Row(
          children: [
            SongArtworkWidget(size: 44, metadata: metadata, borderRadius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metadata.artist ?? 'Musyn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          action(CupertinoIcons.play_rectangle, 'Play Next', () {
            unawaited(audioHandler.playNext(song));
            showToast(context, 'Playing next');
          }),
          action(CupertinoIcons.text_badge_plus, 'Add to Queue', () {
            unawaited(audioHandler.addToQueue(song));
            showToast(context, 'Added to queue');
          }),
          action(
            liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            liked ? 'Remove from Favorites' : 'Add to Favorites',
            () => unawaited(updateSongLikeStatus(id, !liked, songData: song)),
          ),
          action(
            CupertinoIcons.star,
            'Rate & organize',
            () => showTrackOrganizationSheet(context, song),
          ),
          if (!offlineMode.value)
            action(
              CupertinoIcons.plus_circle,
              'Add to Playlist',
              () => showAddToPlaylistDialog(context, song: song),
            ),
          if (current)
            action(
              CupertinoIcons.waveform,
              'Playback source',
              () => showAudioSourcePicker(context, metadata),
            ),
          if (!current && !offline)
            action(CupertinoIcons.arrow_down_circle, 'Download', () async {
              showToast(context, 'Downloading…');
              final ok = await makeSongOffline(song);
              if (context.mounted)
                showToast(
                  context,
                  ok ? 'Saved to downloads' : 'Download failed. Try again.',
                );
            }),
          if (offline)
            action(CupertinoIcons.trash, 'Remove Download', () async {
              await removeSongFromOffline(id);
              if (context.mounted) showToast(context, 'Download removed');
            }, destructive: true),
          action(
            CupertinoIcons.slider_horizontal_3,
            'Download options',
            () => unawaited(
              showDownloadPicker(context, song, (source, quality) async {
                final ok = await makeSongOffline(
                  song,
                  source: source,
                  quality: quality,
                );
                if (context.mounted)
                  showToast(
                    context,
                    ok ? 'Saved to downloads' : 'Download failed. Try again.',
                  );
              }),
            ),
          ),
          if (current)
            action(
              CupertinoIcons.moon,
              'Sleep timer',
              () => showSleepTimerPicker(context),
            ),
          action(
            CupertinoIcons.info_circle,
            'Track Details',
            () => showSongInfoDialog(context, song),
          ),
          if (canRemove && onRemove != null)
            action(
              CupertinoIcons.minus_circle,
              'Remove',
              onRemove,
              destructive: true,
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text('Cancel'),
        ),
      );
    },
  );
}
