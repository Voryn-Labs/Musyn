import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/constants/app_constants.dart';
import 'package:musyn/screens/youtube_auth_webview.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/library_ranking.dart';
import 'package:musyn/utilities/playlist_dialogs.dart';
import 'package:musyn/widgets/account_button.dart';
import 'package:musyn/widgets/catalogue_artwork.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_bar.dart';
import 'package:musyn/widgets/section_header.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    if (YouTubeAuthService().isSignedIn.value) {
      unawaited(YouTubeMusicSyncService().syncPlaylists());
      unawaited(YouTubeMusicSyncService().syncLikedSongs());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark
        ? const Color(0xB3121214)
        : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: musynCanvas(isDark),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          pinnedPlaylistIds,
          offlineMode,
          usePureBlackColor,
          userCustomPlaylists,
          userPlaylistFolders,
          offlinePlaylistService.offlinePlaylists,
          userLikedPlaylists,
          onlinePlaylists,
          YouTubeMusicSyncService().ytMusicPlaylists,
          userPlaylists,
          userOfflineSongs,
          userLikedSongsList,
        ]),
        builder: (context, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text(
                  'Library',
                  style: TextStyle(
                    fontFamily: MusynStyle.displayFont,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                backgroundColor: navBarColor,
                trailing: const AccountButton(),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0x26FFFFFF)
                        : const Color(0x1F000000),
                    width: 0.5,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: commonSingleChildScrollViewPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      ..._buildTopLibrarySections(isDark),
                      const SizedBox(height: 8),
                      _buildPinnedCollections(),
                      _buildFolders(),
                      _buildPlaylistsShelf(isDark),
                      _buildSavedCollections(),
                      const SizedBox(height: 16),
                      if (!offlineMode.value)
                        ..._buildYouTubePlaylistsSections(isDark),
                      const MiniPlayerBottomSpace(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildTopLibrarySections(bool isDark) {
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: musynElevatedSurface(isDark),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ValueListenableBuilder<List>(
              valueListenable: userOfflineSongs,
              builder: (context, offline, _) {
                return PlaylistBar(
                  'Downloaded Songs',
                  subtitle: '${offline.length} tracks',
                  onPressed: () => context.push('/library/downloads'),
                  cubeIcon: CupertinoIcons.arrow_down_circle_fill,
                  borderRadius: commonCustomBarRadiusFirst,
                  showBuildActions: false,
                );
              },
            ),
            ValueListenableBuilder<List>(
              valueListenable: userRecentlyPlayed,
              builder: (context, recents, _) {
                return PlaylistBar(
                  'Recently Played',
                  subtitle: '${recents.length} tracks',
                  onPressed: () => context.push('/library/userSongs/recents'),
                  cubeIcon: CupertinoIcons.clock_fill,
                  showBuildActions: false,
                );
              },
            ),
            ValueListenableBuilder<List>(
              valueListenable: userRecentlyPlayed,
              builder: (context, recents, _) {
                final count = mostPlayedTracks(recents).length;
                return PlaylistBar(
                  'Most Played',
                  subtitle: '$count tracks ranked',
                  onPressed: () =>
                      context.push('/library/userSongs/mostPlayed'),
                  cubeIcon: CupertinoIcons.chart_bar_fill,
                  borderRadius: commonCustomBarRadiusLast,
                  showBuildActions: false,
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  Map<String, Map> _knownCollections() {
    final result = <String, Map>{};
    for (final item in [
      ...playlists,
      ...userCustomPlaylists.value,
      ...userLikedPlaylists.value,
      ...onlinePlaylists.value,
      ...offlinePlaylistService.offlinePlaylists.value,
      ...YouTubeMusicSyncService().ytMusicPlaylists.value,
      for (final folder in userPlaylistFolders.value)
        ...((folder['playlists'] as List?) ?? []),
    ].whereType<Map>()) {
      final id = (item['ytid'] ?? item['playlistId'])?.toString();
      if (id != null && id.isNotEmpty) result[id] = {...item, 'ytid': id};
    }
    return result;
  }

  Widget _buildPinnedCollections() {
    if (pinnedPlaylistIds.value.isEmpty) return const SizedBox.shrink();
    final known = _knownCollections();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Pinned'),
        for (final id in pinnedPlaylistIds.value)
          _collectionRow(known[id] ?? {'ytid': id, 'title': 'Pinned playlist'}),
      ],
    );
  }

  Widget _collectionRow(Map collection) => PlaylistBar(
    collection['title']?.toString() ?? 'Playlist',
    playlistId: collection['ytid']?.toString(),
    playlistArtwork: collection['image']?.toString(),
    playlistData: collection,
  );

  Widget _buildSavedCollections() {
    final ids = <String>{...userPlaylists.value};
    for (final item in [
      ...userLikedPlaylists.value,
      ...offlinePlaylistService.offlinePlaylists.value,
    ].whereType<Map>()) {
      final id = item['ytid']?.toString();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return const SizedBox.shrink();
    final known = _knownCollections();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Saved collections'),
        for (final id in ids)
          _collectionRow(known[id] ?? {'ytid': id, 'title': 'Saved playlist'}),
      ],
    );
  }

  Widget _buildFolders() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(
        title: 'Folders',
        actionButton: CupertinoButton(
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(44, 44),
          onPressed: _createFolder,
          child: const Icon(
            CupertinoIcons.folder_badge_plus,
            semanticLabel: 'Create folder',
          ),
        ),
      ),
      if (userPlaylistFolders.value.isEmpty)
        CupertinoListTile(
          leading: const Icon(CupertinoIcons.folder),
          title: const Text('Organize your playlists'),
          subtitle: const Text('Create your first folder'),
          trailing: const CupertinoListTileChevron(),
          onTap: _createFolder,
        ),
      for (final folder in userPlaylistFolders.value)
        PlaylistBar(
          folder['name']?.toString() ?? 'Folder',
          subtitle: '${(folder['playlists'] as List?)?.length ?? 0} playlists',
          cubeIcon: CupertinoIcons.folder_fill,
          playlistData: {...folder, 'source': 'folder'},
          showBuildActions: false,
          onPressed: () => context.push(
            NavigationPaths.folderPath(
              context,
              folder['id'].toString(),
              folder['name']?.toString() ?? 'Folder',
            ),
          ),
        ),
    ],
  );

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    String? error;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => CupertinoAlertDialog(
          title: const Text('New folder'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: controller,
                autofocus: true,
                placeholder: 'Folder name',
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: CupertinoColors.destructiveRed,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final before = userPlaylistFolders.value.length;
                final message = createPlaylistFolder(controller.text, context);
                if (userPlaylistFolders.value.length > before)
                  Navigator.pop(dialog);
                else
                  update(() => error = message);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _confirmDeletePlaylist(Map playlist) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          'Remove ${playlist['title'] ?? 'this playlist'} from your library?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(dialog);
              removeUserPlaylistEntry(playlist);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsShelf(bool isDark) {
    final custom = getUserCustomPlaylists();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Playlists',
          icon: CupertinoIcons.music_albums_fill,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 156 + 40 * (MediaQuery.textScalerOf(context).scale(14) / 14),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: custom.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _NewPlaylistCard(
                  isDark: isDark,
                  onTap: () => showCreatePlaylistDialog(context),
                );
              }
              if (index == 1)
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: SizedBox(
                    width: 150,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.topLeft,
                      onPressed: () => context.push('/library/userSongs/liked'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: musynSecondarySurface(isDark),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              CupertinoIcons.heart_fill,
                              size: 48,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Liked Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? CupertinoColors.white
                                  : CupertinoColors.black,
                            ),
                          ),
                          Text(
                            '${userLikedSongsList.value.length} tracks',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              final playlist = custom[index - 2];
              final title = playlist['title']?.toString() ?? 'Playlist';
              final id =
                  playlist['playlistId'] ?? playlist['ytid'] ?? playlist['id'];
              final image = playlist['image']?.toString() ?? '';
              final songCount = (playlist['list'] as List?)?.length ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onLongPress: () => PlaylistBar(
                    title,
                    playlistId: id?.toString(),
                    playlistArtwork: image,
                    playlistData: playlist,
                    onDelete: () => _confirmDeletePlaylist(playlist),
                  ).showActions(context),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (id != null) {
                      context.push(
                        NavigationPaths.playlistPath(context, id.toString()),
                        extra: playlist,
                      );
                    }
                  },
                  child: SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: image.isNotEmpty
                                ? CatalogueArtwork(
                                    imageUrl: image,
                                    errorWidget: (_, __, ___) => ColoredBox(
                                      color: musynSecondarySurface(isDark),
                                      child: const Icon(
                                        CupertinoIcons.music_albums,
                                        size: 36,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  )
                                : ColoredBox(
                                    color: musynSecondarySurface(isDark),
                                    child: const Icon(
                                      CupertinoIcons.music_albums,
                                      size: 36,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: MusynStyle.uiFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: isDark
                                ? CupertinoColors.white
                                : CupertinoColors.black,
                          ),
                        ),
                        Text(
                          '$songCount tracks',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: MusynStyle.uiFont,
                            fontSize: 11,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildYouTubePlaylistsSections(bool isDark) {
    return [
      ValueListenableBuilder<bool>(
        valueListenable: YouTubeAuthService().isSignedIn,
        builder: (context, isSignedIn, _) {
          if (!isSignedIn) {
            return _buildSignInBanner(isDark);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'YouTube Music Playlists',
                icon: CupertinoIcons.play_rectangle,
                actionButton: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    CupertinoIcons.arrow_2_circlepath,
                    size: 19,
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.black,
                  ),
                  onPressed: () {
                    unawaited(YouTubeMusicSyncService().fullSync());
                    showToast(context, 'Syncing with YouTube Music...');
                  },
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: YouTubeMusicSyncService().ytMusicPlaylists,
                builder: (context, playlists, _) {
                  if (playlists.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No YouTube playlists found',
                        style: TextStyle(
                          fontFamily: MusynStyle.uiFont,
                          color: CupertinoColors.systemGrey,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height:
                        156 +
                        40 * (MediaQuery.textScalerOf(context).scale(14) / 14),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final title = playlist['title'] ?? 'Unknown';
                        final image = playlist['image'] ?? '';
                        final id = playlist['playlistId']?.toString();

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (id != null) {
                              context.push(
                                NavigationPaths.playlistPath(context, id),
                                extra: {
                                  'title': title,
                                  'image': image,
                                  'ytid': id,
                                  'source': 'user-youtube',
                                },
                              );
                            }
                          },
                          child: Container(
                            width: 150,
                            margin: const EdgeInsets.only(right: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: image.isNotEmpty
                                        ? CatalogueArtwork(
                                            imageUrl: image,
                                            errorWidget: (_, __, ___) =>
                                                ColoredBox(
                                                  color:
                                                      musynSecondarySurface(
                                                        isDark,
                                                      ),
                                                  child: const Icon(
                                                    CupertinoIcons.music_albums,
                                                    color: CupertinoColors
                                                        .systemGrey,
                                                  ),
                                                ),
                                          )
                                        : ColoredBox(
                                            color: musynSecondarySurface(
                                              isDark,
                                            ),
                                            child: const Icon(
                                              CupertinoIcons.music_albums,
                                              color: CupertinoColors.systemGrey,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: MusynStyle.uiFont,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? CupertinoColors.white
                                        : CupertinoColors.black,
                                  ),
                                ),
                                const Text(
                                  'YouTube Music',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: MusynStyle.uiFont,
                                    fontSize: 11,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    ];
  }

  Widget _buildSignInBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: musynElevatedSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.play_rectangle_fill,
              color: Color(0xFFFF0000),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Connect YouTube Music',
                  style: TextStyle(
                    fontFamily: MusynStyle.displayFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sign in to sync your playlists and liked music automatically.',
                  style: TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: isDark ? CupertinoColors.white : CupertinoColors.black,
            borderRadius: BorderRadius.circular(18),
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const YouTubeAuthWebView()),
              );
            },
            child: Text(
              'Sign In',
              style: TextStyle(
                fontFamily: MusynStyle.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? CupertinoColors.black : CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPlaylistCard extends StatelessWidget {
  const _NewPlaylistCard({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: musynElevatedSurface(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0x33FFFFFF)
                      : const Color(0x22000000),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.plus,
                      size: 32,
                      color: isDark
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'New Playlist',
                      style: TextStyle(
                        fontFamily: MusynStyle.uiFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? CupertinoColors.white
                            : CupertinoColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create Playlist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: MusynStyle.uiFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
          ),
          const Text(
            'Custom collection',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: MusynStyle.uiFont,
              fontSize: 11,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}
