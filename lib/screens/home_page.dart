import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/services/audio/audio_runtime.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/jiosaavn_service.dart';
import 'package:musified/services/logger_service.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';
import 'package:musified/widgets/playlist_cube.dart';
import 'package:musified/widgets/section_header.dart';
import 'package:musified/widgets/song_actions_sheet.dart';

/// JioSaavn top-chart playlists (fetched once per app launch).
final ValueNotifier<List<Map<String, dynamic>>> saavnCharts = ValueNotifier([]);

/// YouTube Music chart playlists (Top 100, etc.) fetched once per session.
final ValueNotifier<List<Map<String, dynamic>>> ytChartPlaylists =
    ValueNotifier([]);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _recentsIsList = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    announcementURL.value = null;
    unawaited(_loadTrending());
  }

  Future<void> _loadTrending() async {
    try {
      await Future.wait([
        YouTubeMusicSyncService().fetchTrendingTracks(),
        _loadSaavnCharts(),
        _loadYtChartPlaylists(),
      ]);
    } catch (e) {
      logger.log('Error loading trending: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSaavnCharts() async {
    try {
      if (saavnCharts.value.isNotEmpty) return;
      final charts = await JioSaavnService().fetchTopCharts(limit: 15);
      if (charts.isNotEmpty) saavnCharts.value = charts;
    } catch (e) {
      logger.log('Error loading Saavn charts: $e');
    }
  }

  Future<void> _loadYtChartPlaylists() async {
    try {
      if (ytChartPlaylists.value.isNotEmpty) return;
      final playlists = await YouTubeMusicSyncService().fetchChartPlaylists();
      if (playlists.isNotEmpty) ytChartPlaylists.value = playlists;
    } catch (e) {
      logger.log('Error loading YT chart playlists: $e');
    }
  }

  Future<void> _handleRefresh() async {
    unawaited(HapticFeedback.mediumImpact());
    final futures = <Future<void>>[
      YouTubeMusicSyncService().fetchTrendingTracks(),
      () async {
        final charts = await JioSaavnService().fetchTopCharts(limit: 15);
        if (charts.isNotEmpty) saavnCharts.value = charts;
      }(),
      () async {
        final playlists = await YouTubeMusicSyncService().fetchChartPlaylists();
        if (playlists.isNotEmpty) ytChartPlaylists.value = playlists;
      }(),
    ];
    if (YouTubeAuthService().isSignedIn.value) {
      futures.add(YouTubeMusicSyncService().fullSync());
    }
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: usePureBlackColor,
      builder: (context, _, __) {
        final isDark = isAppDarkMode(context);
        final navBarColor = isDark
            ? const Color(0xB3121214)
            : const Color(0xB3FFFFFF);

        return CupertinoPageScaffold(
          backgroundColor: musifiedCanvas(isDark),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text(
                  'Musified',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.displayFont,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                backgroundColor: navBarColor,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0x26FFFFFF)
                        : const Color(0x1F000000),
                    width: 0.5,
                  ),
                ),
              ),
              CupertinoSliverRefreshControl(onRefresh: _handleRefresh),
              SliverToBoxAdapter(
                child: Padding(
                  padding: commonSingleChildScrollViewPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildHeroShelf(isDark),
                      _buildRecentsShelf(isDark),
                      _buildLikedSongsSection(isDark),
                      _buildTrendingSection(isDark),
                      _buildYtChartsSection(isDark),
                      _buildSaavnChartsSection(isDark),
                      _buildPlaylistsSection(),
                      _buildMostPlayedSection(isDark),
                      if (_isLoading) _buildFeedSkeleton(isDark),
                      _buildEmptyStateIfNeeded(isDark),
                      const MiniPlayerBottomSpace(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroShelf(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: trendingSongs,
      builder: (context, rawSongs, _) {
        final songs = rawSongs.whereType<Map>().toList();
        if (songs.isEmpty) return const SizedBox.shrink();

        final heroSongs = songs.take(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Featured Today',
              icon: CupertinoIcons.sparkles,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 172,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: heroSongs.length,
                itemBuilder: (context, index) {
                  final song = heroSongs[index];
                  return _HeroCard(
                    song: song,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      audioHandler.playPlaylistSong(
                        playlist: {'title': 'Featured Today', 'list': heroSongs},
                        songIndex: index,
                      );
                    },
                    onLongPress: () => showSongActionsSheet(context, song: song),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildRecentsShelf(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: userRecentlyPlayed,
      builder: (context, rawSongs, _) {
        final songs = rawSongs.whereType<Map>().toList();
        if (songs.isEmpty) return const SizedBox.shrink();

        final displayList = songs.take(20).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader(
                  title: 'Recently Played',
                  icon: CupertinoIcons.clock_fill,
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _recentsIsList = !_recentsIsList);
                  },
                  child: Icon(
                    _recentsIsList
                        ? CupertinoIcons.square_grid_2x2
                        : CupertinoIcons.list_bullet,
                    size: 19,
                    color: MusifiedStyle.appleRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentsIsList)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: musifiedElevatedSurface(isDark),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayList.length > 6 ? 6 : displayList.length,
                  separatorBuilder: (_, __) => Container(
                    height: 0.5,
                    margin: const EdgeInsets.only(left: 64),
                    color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
                  ),
                  itemBuilder: (context, index) {
                    final song = displayList[index];
                    return _CompactTrackRow(
                      song: song,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.playPlaylistSong(
                          playlist: {'title': 'Recently Played', 'list': displayList},
                          songIndex: index,
                        );
                      },
                      onLongPress: () => showSongActionsSheet(context, song: song),
                    );
                  },
                ),
              )
            else
              SizedBox(
                height: 205,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final song = displayList[index];
                    return _HomeSongCard(
                      song: song,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        audioHandler.playPlaylistSong(
                          playlist: {'title': 'Recently Played', 'list': displayList},
                          songIndex: index,
                        );
                      },
                      onLongPress: () => showSongActionsSheet(context, song: song),
                    );
                  },
                ),
              ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _buildLikedSongsSection(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: userLikedSongsList,
      builder: (context, rawSongs, _) {
        final songs = rawSongs.whereType<Map>().toList();
        if (songs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Favorites',
              icon: CupertinoIcons.heart_fill,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 205,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: songs.length > 25 ? 25 : songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return _HomeSongCard(
                    song: song,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      audioHandler.playPlaylistSong(
                        playlist: {'title': 'Favorites', 'list': songs},
                        songIndex: index,
                      );
                    },
                    onLongPress: () => showSongActionsSheet(context, song: song),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _buildTrendingSection(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: trendingSongs,
      builder: (context, rawSongs, _) {
        final songs = rawSongs.whereType<Map>().toList();
        if (songs.isEmpty) return const SizedBox.shrink();

        final displayList = songs.skip(8).take(20).toList();
        if (displayList.isEmpty) return const SizedBox.shrink();

        return _buildHorizontalSongSection(
          isDark: isDark,
          title: 'Trending on YouTube',
          icon: CupertinoIcons.flame_fill,
          songs: displayList,
        );
      },
    );
  }

  Widget _buildYtChartsSection(bool isDark) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ytChartPlaylists,
      builder: (context, playlists, _) {
        if (playlists.isEmpty) return const SizedBox.shrink();

        final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'YouTube Charts',
              icon: CupertinoIcons.music_note_list,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: playlistHeight + 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final id = playlist['ytid']?.toString() ?? '';
                  final title = playlist['title']?.toString() ?? 'Chart';

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (id.isNotEmpty) {
                          context.push(
                            '/home/playlist/$id',
                            extra: {'title': title, 'image': playlist['image']},
                          );
                        }
                      },
                      child: SizedBox(
                        width: playlistHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlaylistCube(
                              {
                                'title': title,
                                'image': playlist['image']?.toString() ?? '',
                                'ytid': id,
                              },
                              size: playlistHeight,
                              showTypeLabel: false,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? CupertinoColors.white
                                    : CupertinoColors.black,
                              ),
                            ),
                            Text(
                              playlist['subtitle']?.toString() ??
                                  'YouTube Music',
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
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _buildSaavnChartsSection(bool isDark) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: saavnCharts,
      builder: (context, charts, _) {
        if (charts.isEmpty) return const SizedBox.shrink();

        final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'JioSaavn Charts',
              icon: CupertinoIcons.chart_bar_square_fill,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: playlistHeight + 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: charts.length,
                itemBuilder: (context, index) {
                  final chart = charts[index];
                  final id =
                      chart['saavnPlaylistId']?.toString() ??
                      chart['ytid']?.toString() ??
                      '';
                  final title = chart['title']?.toString() ?? 'Chart';
                  final image = chart['image']?.toString() ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final cleanId = id.startsWith('saavn_chart_')
                            ? id
                            : 'saavn_chart_$id';
                        context.push(
                          '/home/playlist/$cleanId',
                          extra: {
                            'title': title,
                            'image': image,
                            'ytid': cleanId,
                            'saavnPlaylistId': chart['saavnPlaylistId'] ?? id,
                            'source': 'saavn',
                            'type': 'chart',
                          },
                        );
                      },
                      child: SizedBox(
                        width: playlistHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlaylistCube(
                              {'title': title, 'image': image, 'ytid': id},
                              size: playlistHeight,
                              showTypeLabel: false,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: isDark
                                    ? CupertinoColors.white
                                    : CupertinoColors.black,
                              ),
                            ),
                            Text(
                              chart['subtitle']?.toString() ?? 'JioSaavn',
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
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _buildMostPlayedSection(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: userRecentlyPlayed,
      builder: (context, rawSongs, _) {
        final songs = rawSongs.whereType<Map>().toList();
        final ranked =
            songs.where((song) {
              final count = song['listeningCount'];
              return count is num && count > 0;
            }).toList()..sort((a, b) {
              final aCount = (a['listeningCount'] as num?)?.toInt() ?? 0;
              final bCount = (b['listeningCount'] as num?)?.toInt() ?? 0;
              return bCount.compareTo(aCount);
            });
        if (ranked.isEmpty) return const SizedBox.shrink();

        final displayList = ranked.take(25).toList();
        return _buildHorizontalSongSection(
          isDark: isDark,
          title: 'My Most Played',
          icon: CupertinoIcons.chart_bar_fill,
          songs: displayList,
        );
      },
    );
  }

  Widget _buildHorizontalSongSection({
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Map> songs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, icon: icon),
        const SizedBox(height: 10),
        SizedBox(
          height: 205,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return _HomeSongCard(
                song: song,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  audioHandler.playPlaylistSong(
                    playlist: {'title': title, 'list': songs},
                    songIndex: index,
                  );
                },
                onLongPress: () => showSongActionsSheet(context, song: song),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildPlaylistsSection() {
    return ValueListenableBuilder<List<Map>>(
      valueListenable: userCustomPlaylists,
      builder: (context, customPlaylists, _) {
        if (customPlaylists.isEmpty) return const SizedBox.shrink();

        final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'My Playlists',
              icon: CupertinoIcons.music_albums_fill,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: playlistHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: customPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = customPlaylists[index];
                  final id =
                      playlist['playlistId'] ??
                      playlist['ytid'] ??
                      playlist['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (id != null) {
                          context.push(
                            '/home/playlist/$id',
                            extra: {
                              'title': playlist['title'],
                              'image': playlist['image'],
                            },
                          );
                        }
                      },
                      child: PlaylistCube(playlist, size: playlistHeight),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _buildFeedSkeleton(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 300,
          height: 170,
          decoration: BoxDecoration(
            color: musifiedElevatedSurface(isDark),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: List.generate(
            3,
            (index) => Container(
              width: 140,
              height: 180,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: musifiedElevatedSurface(isDark),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmptyStateIfNeeded(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        userLikedSongsList,
        userRecentlyPlayed,
        userCustomPlaylists,
        trendingSongs,
      ]),
      builder: (context, _) {
        final hasAny =
            userLikedSongsList.value.isNotEmpty ||
            userRecentlyPlayed.value.isNotEmpty ||
            userCustomPlaylists.value.isNotEmpty ||
            trendingSongs.value.isNotEmpty;

        if (hasAny) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.music_note_2,
                  size: 56,
                  color: MusifiedStyle.appleRed,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Music Library',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.displayFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Songs you like and play will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.song,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  final Map song;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final title = song['title']?.toString() ?? 'Featured';
    final artist = song['artist']?.toString() ?? '';
    final imageUrl =
        song['highResImage'] ?? song['image'] ?? song['lowResImage'] ?? '';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 300,
        height: 172,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.toString().isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl.toString(),
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: musifiedSecondarySurface(isDark),
                    child: const Icon(
                      CupertinoIcons.music_note,
                      size: 40,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: musifiedSecondarySurface(isDark),
                  child: const Icon(
                    CupertinoIcons.music_note,
                    size: 40,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00000000),
                      Color(0x55000000),
                      Color(0xCC000000),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 0.65, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 56,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: MusifiedStyle.displayFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: CupertinoColors.white,
                      ),
                    ),
                    if (artist.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: MusifiedStyle.uiFont,
                          fontSize: 12,
                          color: Color(0xB8FFFFFF),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: MusifiedStyle.appleRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    size: 16,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTrackRow extends StatelessWidget {
  const _CompactTrackRow({
    required this.song,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  final Map song;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final title = song['title']?.toString() ?? 'Track';
    final artist = song['artist']?.toString() ?? '';
    final imageUrl =
        song['highResImage'] ?? song['image'] ?? song['lowResImage'] ?? '';
    final currentPlaying = audioHandler.currentPlayingYtid.value;
    final isCurrent = currentPlaying != null && currentPlaying == song['ytid'];

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 44,
                height: 44,
                child: imageUrl.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl.toString(),
                        fit: BoxFit.cover,
                        memCacheWidth: 88,
                        memCacheHeight: 88,
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: musifiedSecondarySurface(isDark),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            size: 18,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      )
                    : ColoredBox(
                        color: musifiedSecondarySurface(isDark),
                        child: const Icon(
                          CupertinoIcons.music_note,
                          size: 18,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isCurrent
                          ? MusifiedStyle.appleRed
                          : (isDark
                              ? CupertinoColors.white
                              : CupertinoColors.black),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            if (onLongPress != null)
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: onLongPress,
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeSongCard extends StatelessWidget {
  const _HomeSongCard({
    required this.song,
    required this.onTap,
    required this.isDark,
    this.onLongPress,
  });

  final Map song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = song['title']?.toString() ?? 'Unknown';
    final artist = song['artist']?.toString() ?? '';
    final imageUrl =
        song['highResImage'] ?? song['image'] ?? song['lowResImage'] ?? '';
    final primaryColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    const secondaryColor = CupertinoColors.systemGrey;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: imageUrl.toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl.toString(),
                            fit: BoxFit.cover,
                            memCacheWidth: 280,
                            memCacheHeight: 280,
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: musifiedSecondarySurface(isDark),
                              child: const Icon(
                                CupertinoIcons.music_note,
                                size: 36,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: musifiedSecondarySurface(isDark),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              size: 36,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.play_fill,
                      size: 13,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 12,
                color: secondaryColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
