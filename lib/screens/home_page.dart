import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/constants/app_constants.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/discovery_state.dart';
import 'package:musyn/services/jiosaavn_service.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/library_ranking.dart';
import 'package:musyn/widgets/account_button.dart';
import 'package:musyn/widgets/catalogue_artwork.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/discovery_links.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_cube.dart';
import 'package:musyn/widgets/section_header.dart';
import 'package:musyn/widgets/song_actions_sheet.dart';

export 'package:musyn/services/discovery_state.dart'
    show saavnCharts, ytChartPlaylists;

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.loadFeed});
  final Future<void> Function()? loadFeed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _recentsIsList = false;
  bool _isLoading = true;
  bool _feedFailed = false;
  int _feedRequest = 0;

  @override
  void initState() {
    super.initState();
    announcementURL.value = null;
    unawaited(_loadTrending());
  }

  Future<void> _loadTrending({bool refresh = false}) async {
    final request = ++_feedRequest;
    final country = chartCountry.value;
    setState(() {
      _isLoading = true;
      _feedFailed = false;
    });
    var failed = false;
    Future<void> load(Future<void> Function() fetch) async {
      try {
        await fetch().timeout(const Duration(seconds: 15));
      } catch (error) {
        failed = true;
        logger.log('Home feed section failed', error: error);
      }
    }

    if (widget.loadFeed != null) {
      await load(widget.loadFeed!);
    } else {
      await Future.wait([
        load(() async {
          await YouTubeMusicSyncService().fetchTrendingTracks();
          if (trendingError.value != null) failed = true;
        }),
        if (jiosaavnEnabled.value)
          load(() async {
            if (!refresh && saavnCharts.value.isNotEmpty) return;
            final charts = await JioSaavnService().fetchTopCharts(limit: 15);
            if (charts.isEmpty) {
              failed = true;
            } else {
              saavnCharts.value = charts;
            }
          }),
        load(() async {
          if (!refresh && ytChartPlaylists.value.isNotEmpty) return;
          final charts = await YouTubeMusicSyncService().fetchChartPlaylists();
          if (charts.isEmpty) {
            failed = true;
          } else {
            if (country == chartCountry.value) ytChartPlaylists.value = charts;
          }
        }),
      ]);
    }
    if (mounted && request == _feedRequest)
      setState(() {
        _isLoading = false;
        _feedFailed = failed;
      });
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadTrending(refresh: true),
      if (YouTubeAuthService().isSignedIn.value)
        YouTubeMusicSyncService()
            .fullSync()
            .timeout(const Duration(seconds: 20))
            .catchError((Object _) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([usePureBlackColor, jiosaavnEnabled]),
      builder: (context, _) {
        final isDark = isAppDarkMode(context);
        final navBarColor = isDark
            ? const Color(0xB3121214)
            : const Color(0xB3FFFFFF);

        return CupertinoPageScaffold(
          backgroundColor: musynCanvas(isDark),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverNavigationBar(
                trailing: const AccountButton(),
                largeTitle: const Text(
                  'Listen now',
                  style: TextStyle(
                    fontFamily: MusynStyle.displayFont,
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
                      if (jiosaavnEnabled.value)
                        _buildSaavnChartsSection(isDark),
                      _buildPlaylistsSection(),
                      _buildMostPlayedSection(isDark),
                      if (_isLoading) _buildFeedSkeleton(isDark),
                      if (_feedFailed && !_isLoading)
                        if (_hasAnySongs)
                          _buildRefreshBanner(isDark)
                        else
                          Column(
                            children: [
                              ContentState(
                                icon: CupertinoIcons.wifi_exclamationmark,
                                title: 'Some music could not be refreshed',
                                message:
                                    'Your saved music is still available. Retry to refresh the catalogues.',
                                actionLabel: 'Refresh music',
                                onAction: _handleRefresh,
                              ),
                              const DiscoveryLinks(),
                            ],
                          ),
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
              height:
                  (MediaQuery.sizeOf(context).width * .7).clamp(0, 320) / .92,
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
                        playlist: {
                          'title': 'Featured Today',
                          'list': heroSongs,
                        },
                        songIndex: index,
                      );
                    },
                    onLongPress: () =>
                        showSongActionsSheet(context, song: song),
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
                const Expanded(
                  child: SectionHeader(
                    title: 'Recently Played',
                    icon: CupertinoIcons.clock_fill,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _recentsIsList = !_recentsIsList);
                  },
                  child: Icon(
                    _recentsIsList
                        ? CupertinoIcons.square_grid_2x2
                        : CupertinoIcons.list_bullet,
                    size: 19,
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentsIsList)
              SizedBox(
                height: 256,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: (displayList.length / 4).ceil(),
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, column) => SizedBox(
                    width: MediaQuery.sizeOf(context).width - 64,
                    child: Column(
                      children: [
                        for (var row = 0; row < 4; row++)
                          if (column * 4 + row < displayList.length)
                            SizedBox(
                              height: 64,
                              child: _CompactTrackRow(
                                song: displayList[column * 4 + row],
                                isDark: isDark,
                                onTap: () => audioHandler.playPlaylistSong(
                                  playlist: {
                                    'title': 'Recently Played',
                                    'list': displayList,
                                  },
                                  songIndex: column * 4 + row,
                                ),
                                onLongPress: () => showSongActionsSheet(
                                  context,
                                  song: displayList[column * 4 + row],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
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
                          playlist: {
                            'title': 'Recently Played',
                            'list': displayList,
                          },
                          songIndex: index,
                        );
                      },
                      onLongPress: () =>
                          showSongActionsSheet(context, song: song),
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
                    onLongPress: () =>
                        showSongActionsSheet(context, song: song),
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
        final ranked = mostPlayedTracks(rawSongs);
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

        const playlistHeight = 150.0;

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
                                fontFamily: MusynStyle.uiFont,
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

        const playlistHeight = 150.0;

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
                                fontFamily: MusynStyle.uiFont,
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
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistsSection() {
    return ValueListenableBuilder<List<Map>>(
      valueListenable: userCustomPlaylists,
      builder: (context, customPlaylists, _) {
        if (customPlaylists.isEmpty) return const SizedBox.shrink();

        const playlistHeight = 150.0;

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
          width: (MediaQuery.sizeOf(context).width * .7).clamp(0, 320),
          height: (MediaQuery.sizeOf(context).width * .7).clamp(0, 320) / .92,
          decoration: BoxDecoration(
            color: musynElevatedSurface(isDark),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => Container(
              width: 140,
              height: 180,
              decoration: BoxDecoration(
                color: musynElevatedSurface(isDark),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRefreshBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0D000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x10000000),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.wifi_exclamationmark,
            size: 18,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Some music could not be refreshed',
              style: TextStyle(
                fontFamily: MusynStyle.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            onPressed: _handleRefresh,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontFamily: MusynStyle.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MusynStyle.appleRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasAnySongs =>
      userLikedSongsList.value.isNotEmpty ||
      userRecentlyPlayed.value.isNotEmpty ||
      userCustomPlaylists.value.isNotEmpty ||
      trendingSongs.value.isNotEmpty ||
      ytChartPlaylists.value.isNotEmpty ||
      (jiosaavnEnabled.value && saavnCharts.value.isNotEmpty);

  Widget _buildEmptyStateIfNeeded(bool isDark) => AnimatedBuilder(
    animation: Listenable.merge([
      userLikedSongsList,
      userRecentlyPlayed,
      userCustomPlaylists,
      trendingSongs,
      ytChartPlaylists,
      saavnCharts,
    ]),
    builder: (context, _) {
      final hasAny = _hasAnySongs;
      if (hasAny || _isLoading || _feedFailed) return const SizedBox.shrink();
      return Column(
        children: [
          ContentState(
            title: 'Make yourself at home',
            message:
                'Find a song to start listening. Favorites, recent tracks and your playlists will appear here.',
            actionLabel: 'Find music',
            onAction: () => context.go('/search'),
          ),
          const DiscoveryLinks(),
        ],
      );
    },
  );
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
        width: (MediaQuery.sizeOf(context).width * .7).clamp(0, 320),
        height: (MediaQuery.sizeOf(context).width * .7).clamp(0, 320) / .92,
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
                CatalogueArtwork(
                  imageUrl: imageUrl.toString(),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: musynSecondarySurface(isDark),
                    child: const Icon(
                      CupertinoIcons.music_note,
                      size: 40,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: musynSecondarySurface(isDark),
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
                right: 16,
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
                        fontFamily: MusynStyle.displayFont,
                        fontSize: 20,
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
                          fontFamily: MusynStyle.uiFont,
                          fontSize: 14,
                          color: Color(0xB8FFFFFF),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
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
                    ? CatalogueArtwork(
                        imageUrl: imageUrl.toString(),
                        memCacheWidth: 88,
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: musynSecondarySurface(isDark),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            size: 18,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      )
                    : ColoredBox(
                        color: musynSecondarySurface(isDark),
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
                      fontFamily: MusynStyle.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isCurrent
                          ? (isDark
                                ? CupertinoColors.white
                                : CupertinoColors.black)
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
                      fontFamily: MusynStyle.uiFont,
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
        width: 150,
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
                        ? CatalogueArtwork(
                            imageUrl: imageUrl.toString(),
                            memCacheWidth: 280,
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: musynSecondarySurface(isDark),
                              child: const Icon(
                                CupertinoIcons.music_note,
                                size: 36,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: musynSecondarySurface(isDark),
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
                fontFamily: MusynStyle.uiFont,
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
                fontFamily: MusynStyle.uiFont,
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
