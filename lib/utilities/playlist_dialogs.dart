import 'package:flutter/cupertino.dart';
import 'package:musyn/extensions/l10n.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/utilities/flutter_toast.dart';

void showCreatePlaylistDialog(
  BuildContext context, {
  dynamic songToAdd,
  List<dynamic>? songsToAdd,
  String? folderId,
}) {
  final nameController = TextEditingController();
  final linkController = TextEditingController();
  var isCustom = true;
  var busy = false;
  String? error;
  showCupertinoModalPopup<void>(
    context: context,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, update) {
        final dark = isAppDarkMode(sheet);
        final foreground = CupertinoTheme.of(sheet).primaryContrastingColor;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * .85,
            ),
            decoration: BoxDecoration(
              color: musynSheetCard(dark),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey3,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'New Playlist',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<bool>(
                        groupValue: isCustom,
                        children: const {
                          true: Text('Custom'),
                          false: Text('YouTube Link'),
                        },
                        onValueChanged: (value) {
                          if (!busy && value != null)
                            update(() {
                              isCustom = value;
                              error = null;
                            });
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    CupertinoTextField(
                      controller: isCustom ? nameController : linkController,
                      enabled: !busy,
                      placeholder: isCustom
                          ? 'Playlist name'
                          : 'YouTube playlist URL',
                      padding: const EdgeInsets.all(14),
                      onChanged: (_) {
                        if (error != null) update(() => error = null);
                      },
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: CupertinoColors.destructiveRed,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            onPressed: busy ? null : () => Navigator.pop(sheet),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoButton.filled(
                            onPressed: busy
                                ? null
                                : () async {
                                    final value =
                                        (isCustom
                                                ? nameController
                                                : linkController)
                                            .text
                                            .trim();
                                    if (value.isEmpty) {
                                      update(
                                        () => error = isCustom
                                            ? 'Enter a playlist name.'
                                            : 'Enter a YouTube playlist link.',
                                      );
                                      return;
                                    }
                                    if (isCustom) {
                                      final result = createCustomPlaylist(
                                        value,
                                        null,
                                        context,
                                      );
                                      final entries =
                                          songsToAdd ??
                                          (songToAdd is Map
                                              ? [songToAdd]
                                              : <dynamic>[]);
                                      if (entries.isNotEmpty)
                                        addSongsInCustomPlaylist(
                                          context,
                                          result.$2,
                                          entries.whereType<Map>().toList(),
                                        );
                                      if (folderId != null) {
                                        final playlist =
                                            getUserCustomPlaylists().firstWhere(
                                              (p) => p['ytid'] == result.$2,
                                            );
                                        movePlaylistToFolder(
                                          playlist,
                                          folderId,
                                          context,
                                        );
                                      }
                                      Navigator.pop(sheet);
                                      showToast(context, result.$1);
                                    } else {
                                      update(() {
                                        busy = true;
                                        error = null;
                                      });
                                      final before = userPlaylists.value.length;
                                      try {
                                        final result = await addUserPlaylist(
                                          value,
                                          context,
                                        );
                                        if (!sheet.mounted) return;
                                        if (userPlaylists.value.length >
                                            before) {
                                          Navigator.pop(sheet);
                                          if (context.mounted)
                                            showToast(context, result);
                                        } else
                                          update(
                                            () => error =
                                                'This playlist could not be added. Check the link, your connection, and whether it is already saved.',
                                          );
                                      } catch (_) {
                                        if (sheet.mounted)
                                          update(
                                            () => error =
                                                'This playlist could not be added. Try again.',
                                          );
                                      } finally {
                                        if (sheet.mounted)
                                          update(() => busy = false);
                                      }
                                    }
                                  },
                            child: busy
                                ? CupertinoActivityIndicator(color: foreground)
                                : const Text('Create'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  ).whenComplete(() {
    nameController.dispose();
    linkController.dispose();
  });
}

void showAddToPlaylistDialog(
  BuildContext context, {
  dynamic song,
  List<Map>? songs,
}) {
  final entries = songs ?? (song is Map ? [song] : <Map>[]);
  if (entries.isEmpty) {
    showToast(context, 'No tracks to add');
    return;
  }
  final ytSync = YouTubeMusicSyncService();
  final ytAuth = YouTubeAuthService();

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: Listenable.merge([
        userCustomPlaylists,
        ytSync.ytMusicPlaylists,
        ytAuth.isSignedIn,
      ]),
      builder: (context, _) {
        final custom = getUserCustomPlaylists();
        final ytPlaylists = ytAuth.isSignedIn.value
            ? ytSync.ytMusicPlaylists.value
            : <Map<String, dynamic>>[];
        final hasTargets = custom.isNotEmpty || ytPlaylists.isNotEmpty;

        final actions = <Widget>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showCreatePlaylistDialog(context, songsToAdd: entries);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.plus_circle, size: 20),
                SizedBox(width: 8),
                Text('New Custom Playlist...'),
              ],
            ),
          ),
        ];

        if (ytAuth.isSignedIn.value) {
          actions.add(
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                showCreateYouTubeMusicPlaylistDialog(
                  context,
                  songsToAdd: entries,
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.play_rectangle, size: 20),
                  SizedBox(width: 8),
                  Text('New YouTube Music Playlist...'),
                ],
              ),
            ),
          );
        }

        if (custom.isNotEmpty) {
          for (final playlist in custom) {
            final name = playlist['title']?.toString() ?? 'Custom Playlist';
            final id = playlist['ytid']?.toString() ?? '';
            actions.add(
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (id.isNotEmpty) {
                    final result = addSongsInCustomPlaylist(
                      context,
                      id,
                      entries,
                    );
                    showToast(context, result);
                  }
                },
                child: Text('My · $name'),
              ),
            );
          }
        }

        if (ytPlaylists.isNotEmpty) {
          for (final playlist in ytPlaylists) {
            final name = playlist['title']?.toString() ?? 'Playlist';
            final id = playlist['playlistId']?.toString() ?? '';
            if (id.isEmpty) continue;
            actions.add(
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final result = await addSongsToYouTubeMusicPlaylist(
                    context,
                    id,
                    entries,
                  );
                  if (context.mounted) {
                    showToast(context, result);
                  }
                },
                child: Text('YouTube · $name'),
              ),
            );
          }
        }

        return CupertinoActionSheet(
          title: Text(
            entries.length == 1
                ? 'Add Track to Playlist'
                : 'Add ${entries.length} Tracks to Playlist',
          ),
          message: hasTargets
              ? null
              : const Text('Create a playlist to save this track'),
          actions: actions,
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        );
      },
    ),
  );
}

void showCreateYouTubeMusicPlaylistDialog(
  BuildContext context, {
  Map? songToAdd,
  List<Map>? songsToAdd,
}) {
  final nameController = TextEditingController();
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('YouTube Music Playlist'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: nameController,
          placeholder: 'Playlist name',
          autofocus: true,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () async {
            final name = nameController.text.trim();
            Navigator.pop(ctx);
            if (name.isEmpty) return;
            final result = await createYouTubeMusicPlaylist(
              name,
              songToAdd,
              context,
              songsToAdd: songsToAdd,
            );
            if (context.mounted) {
              showToast(context, result);
            }
          },
          child: Text(context.l10n.create),
        ),
      ],
    ),
  ).whenComplete(nameController.dispose);
}
