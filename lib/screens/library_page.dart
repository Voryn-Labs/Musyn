import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/screens/youtube_auth_webview.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/navigation_paths.dart';
import 'package:musified/services/playlist_download_service.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/playlist_dialogs.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';
import 'package:musified/widgets/playlist_bar.dart';
import 'package:musified/widgets/section_header.dart';

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
      backgroundColor: musifiedCanvas(isDark),
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
          userPlaylists,
          userOfflineSongs,
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
                    fontFamily: MusifiedStyle.displayFont,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                backgroundColor: navBarColor,
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => showCreatePlaylistDialog(context),
                  child: const Icon(
                    CupertinoIcons.plus,
                    size: 22,
                    color: MusifiedStyle.appleRed,
                  ),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: commonSingleChildScrollViewPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      ..._buildTopLibrarySections(isDark),
                      const SizedBox(height: 8),
                      _buildPlaylistsShelf(isDark),
                      const SizedBox(height: 16),
                      if (!offlineMode.value) ..._buildYouTubePlaylistsSections(isDark),
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
          color: musifiedElevatedSurface(isDark),
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
                  onPressed: () => context.go('/library/userSongs/offline'),
                  cubeIcon: CupertinoIcons.arrow_down_circle_fill,
                  borderRadius: commonCustomBarRadiusFirst,
                  showBuildActions: false,
                );
              },
            ),
            ValueListenableBuilder<List>(
              valueListenable: userLikedSongsList,
              builder: (context, liked, _) {
                return PlaylistBar(
                  'Favorite Tracks',
                  subtitle: '${liked.length} tracks',
                  onPressed: () => context.go('/library/userSongs/liked'),
                  cubeIcon: CupertinoIcons.heart_fill,
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
                  onPressed: () => context.go('/library/userSongs/recents'),
                  cubeIcon: CupertinoIcons.clock_fill,
                  showBuildActions: false,
                );
              },
            ),
            ValueListenableBuilder<List>(
              valueListenable: userRecentlyPlayed,
              builder: (context, recents, _) {
                final count = recents.length;
                return PlaylistBar(
                  'Most Played',
                  subtitle: '$count tracks ranked',
                  onPressed: () => context.go('/library/userSongs/mostPlayed'),
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
          height: 196,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: custom.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _NewPlaylistCard(
                  isDark: isDark,
                  onTap: () => showCreatePlaylistDialog(context),
                );
              }
              final playlist = custom[index - 1];
              final title = playlist['title']?.toString() ?? 'Playlist';
              final id = playlist['playlistId'] ?? playlist['ytid'] ?? playlist['id'];
              final image = playlist['image']?.toString() ?? '';
              final songCount = (playlist['list'] as List?)?.length ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (id != null) {
                      context.push(
                        '/library/playlist/$id',
                        extra: {'title': title, 'image': image},
                      );
                    }
                  },
                  child: SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: image.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: image,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => ColoredBox(
                                      color: musifiedSecondarySurface(isDark),
                                      child: const Icon(
                                        CupertinoIcons.music_albums,
                                        size: 36,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  )
                                : ColoredBox(
                                    color: musifiedSecondarySurface(isDark),
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
                            fontFamily: MusifiedStyle.uiFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: isDark ? CupertinoColors.white : CupertinoColors.black,
                          ),
                        ),
                        Text(
                          '$songCount tracks',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: MusifiedStyle.uiFont,
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
                  child: const Icon(
                    CupertinoIcons.arrow_2_circlepath,
                    size: 19,
                    color: MusifiedStyle.appleRed,
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
                          fontFamily: MusifiedStyle.uiFont,
                          color: CupertinoColors.systemGrey,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height: 196,
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
                            width: 140,
                            margin: const EdgeInsets.only(right: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: image.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: image,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                ColoredBox(
                                                  color: musifiedSecondarySurface(isDark),
                                                  child: const Icon(
                                                    CupertinoIcons.music_albums,
                                                    color: CupertinoColors.systemGrey,
                                                  ),
                                                ),
                                          )
                                        : ColoredBox(
                                            color: musifiedSecondarySurface(isDark),
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
                                    fontFamily: MusifiedStyle.uiFont,
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
                                    fontFamily: MusifiedStyle.uiFont,
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
        color: musifiedElevatedSurface(isDark),
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
                    fontFamily: MusifiedStyle.displayFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sign in to sync your playlists and liked music automatically.',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
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
            color: MusifiedStyle.appleRed,
            borderRadius: BorderRadius.circular(18),
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const YouTubeAuthWebView(),
                ),
              );
            },
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewPlaylistCard extends StatelessWidget {
  const _NewPlaylistCard({
    required this.isDark,
    required this.onTap,
  });

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: musifiedElevatedSurface(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
                  width: 1.2,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.plus,
                      size: 32,
                      color: MusifiedStyle.appleRed,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'New Playlist',
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MusifiedStyle.appleRed,
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
              fontFamily: MusifiedStyle.uiFont,
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
              fontFamily: MusifiedStyle.uiFont,
              fontSize: 11,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}
