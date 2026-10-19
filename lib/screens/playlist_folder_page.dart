import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/constants/app_constants.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/app_utils.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/musyn_picker_sheet.dart';
import 'package:musyn/utilities/playlist_dialogs.dart';
import 'package:musyn/utilities/playlist_utils.dart';
import 'package:musyn/widgets/confirmation_dialog.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_bar.dart';

class PlaylistFolderPage extends StatefulWidget {
  const PlaylistFolderPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  final String folderId;
  final String folderName;

  @override
  State<PlaylistFolderPage> createState() => _PlaylistFolderPageState();
}

class _PlaylistFolderPageState extends State<PlaylistFolderPage> {
  late String _folderName;
  bool _loadingCandidates = false;

  @override
  void initState() {
    super.initState();
    _folderName = widget.folderName;
  }

  void _showFolderActions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(_folderName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddPlaylistDialog();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.plus, size: 20),
                SizedBox(width: 8),
                Text('Add Playlist to Folder'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showRenameFolderDialog();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.pencil, size: 20),
                SizedBox(width: 8),
                Text('Rename Folder'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteFolderDialog();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.trash,
                  size: 20,
                  color: CupertinoColors.destructiveRed,
                ),
                SizedBox(width: 8),
                Text('Delete Folder'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark
        ? const Color(0xB3121214)
        : const Color(0xB3FFFFFF);

    return ValueListenableBuilder<List>(
      valueListenable: userPlaylistFolders,
      builder: (context, _, __) {
        if (!userPlaylistFolders.value.whereType<Map>().any(
          (folder) => folder['id'] == widget.folderId,
        )) {
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Folder unavailable'),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: ContentState(
                  title: 'This folder is no longer available',
                  message:
                      'Choose another folder or create one in your library.',
                  actionLabel: 'Open library',
                  onAction: () => context.go('/library'),
                ),
              ),
            ),
          );
        }
        final isOffline = offlineMode.value;
        final playlists = isOffline
            ? getPlaylistsInFolder(
                widget.folderId,
              ).where(PlaylistUtils.isPlaylistOffline).toList()
            : getPlaylistsInFolder(widget.folderId);

        return CupertinoPageScaffold(
          backgroundColor: isDark
              ? const Color(0xFF000000)
              : const Color(0xFFFFFFFF),
          navigationBar: CupertinoNavigationBar(
            middle: Text(
              _folderName,
              style: const TextStyle(
                fontFamily: MusynStyle.displayFont,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: navBarColor,
            trailing: _loadingCandidates
                ? const CupertinoActivityIndicator()
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showFolderActions,
                    child: const Icon(CupertinoIcons.ellipsis, size: 22),
                  ),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0x26FFFFFF)
                    : const Color(0x1F000000),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: musynSecondarySurface(isDark),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              CupertinoIcons.folder_fill,
                              size: 48,
                              color: MusynStyle.appleRed,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${playlists.length} playlists',
                            style: const TextStyle(
                              fontFamily: MusynStyle.uiFont,
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (playlists.isEmpty)
                  SliverToBoxAdapter(
                    child: ContentState(
                      icon: CupertinoIcons.folder,
                      loading: _loadingCandidates,
                      title: _loadingCandidates
                          ? 'Loading your playlists'
                          : 'This folder is ready for music',
                      message:
                          'Add a playlist to keep your collections organized.',
                      actionLabel: 'Add a playlist',
                      onAction: _loadingCandidates
                          ? null
                          : _showAddPlaylistDialog,
                    ),
                  )
                else
                  SliverPadding(
                    padding: commonListViewBottomPadding,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final playlist = playlists[index];
                        final borderRadius = getItemBorderRadius(
                          index,
                          playlists.length,
                        );
                        return PlaylistBar(
                          key: ValueKey(
                            'folder_playlist_${playlist['ytid']}_$index',
                          ),
                          playlist['title'],
                          playlistId: playlist['ytid'],
                          playlistArtwork: playlist['image'],
                          playlistData: playlist,
                          onDelete: () => _showRemovePlaylistDialog(playlist),
                          borderRadius: borderRadius,
                        );
                      }, childCount: playlists.length),
                    ),
                  ),
                const SliverMiniPlayerBottomSpace(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddPlaylistDialog() async {
    if (_loadingCandidates) return;
    setState(() => _loadingCandidates = true);
    final customCandidates = getPlaylistsNotInFolders();
    var youtubeCandidates = <dynamic>[];
    try {
      youtubeCandidates = await getUserPlaylistsNotInFolders().timeout(
        const Duration(seconds: 15),
      );
    } catch (_) {
      if (mounted)
        showToast(context, 'Some online playlists could not be loaded.');
    } finally {
      if (mounted) setState(() => _loadingCandidates = false);
    }
    final candidates = [...customCandidates, ...youtubeCandidates];

    if (!mounted) return;

    if (candidates.isEmpty) {
      showCreatePlaylistDialog(context, folderId: widget.folderId);
      return;
    }

    await showMusynPickerSheet(
      context,
      title: 'Add to Folder',
      emptyMessage: 'No playlists available',
      actions: [
        for (final playlist in candidates)
          PickerSheetAction(
            label: playlist['title']?.toString() ?? '',
            icon: CupertinoIcons.list_bullet,
            onTap: () {
              movePlaylistToFolder(playlist, widget.folderId, context);
            },
          ),
      ],
    );
  }

  void _showRemovePlaylistDialog(Map playlist) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        submitMessage: 'Remove',
        confirmationMessage: 'Remove this playlist from the folder?',
        onCancel: () => Navigator.of(ctx).pop(),
        onSubmit: () {
          Navigator.of(ctx).pop();
          movePlaylistToFolder(playlist, null, context);
        },
      ),
    );
  }

  Future<void> _showRenameFolderDialog() async {
    var newName = _folderName;
    final controller = TextEditingController(text: newName);

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Rename Folder'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Folder Name',
            autofocus: true,
            onChanged: (val) => newName = val,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              final result = renamePlaylistFolder(
                widget.folderId,
                newName,
                context,
              );
              showToast(context, result);
              if (newName.trim().isNotEmpty) {
                setState(() => _folderName = newName.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void _showDeleteFolderDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        submitMessage: 'Delete',
        confirmationMessage: 'Delete this folder and all its contents?',
        isDangerous: true,
        onCancel: () => Navigator.of(ctx).pop(),
        onSubmit: () {
          Navigator.of(ctx).pop();
          deletePlaylistFolder(widget.folderId, context);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
