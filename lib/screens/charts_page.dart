import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/discovery_state.dart';
import 'package:musyn/services/jiosaavn_service.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_artwork.dart';
import 'package:musyn/widgets/playlist_bar.dart';

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key, this.loadYoutube, this.loadSaavn});
  final Future<List<Map<String, dynamic>>> Function()? loadYoutube;
  final Future<List<Map<String, dynamic>>> Function()? loadSaavn;
  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  String _provider = 'youtube';
  bool _loading = true;
  final _errors = <String>{};
  int _request = 0;

  @override
  void initState() {
    super.initState();
    offlineMode.addListener(_modeChanged);
    jiosaavnEnabled.addListener(_modeChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    offlineMode.removeListener(_modeChanged);
    jiosaavnEnabled.removeListener(_modeChanged);
    super.dispose();
  }

  void _modeChanged() {
    if (!jiosaavnEnabled.value) _provider = 'youtube';
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    if (offlineMode.value) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _errors.clear();
    });
    Future<void> section(
      String provider,
      Future<List<Map<String, dynamic>>> Function() fetch,
      ValueNotifier<List<Map<String, dynamic>>> target,
    ) async {
      try {
        final items = await fetch().timeout(const Duration(seconds: 15));
        if (!mounted || request != _request) return;
        setState(() {
          if (items.isNotEmpty) {
            target.value = items;
          } else {
            _errors.add(provider);
          }
        });
      } catch (_) {
        if (mounted && request == _request) {
          setState(() => _errors.add(provider));
        }
      }
    }

    await Future.wait([
      section(
        'youtube',
        widget.loadYoutube ?? YouTubeMusicSyncService().fetchChartPlaylists,
        ytChartPlaylists,
      ),
      if (jiosaavnEnabled.value)
        section(
          'jiosaavn',
          widget.loadSaavn ?? () => JioSaavnService().fetchTopCharts(limit: 20),
          saavnCharts,
        ),
    ]);
    if (mounted && request == _request) setState(() => _loading = false);
  }

  void _openPlaylist(BuildContext context, Map<String, dynamic> playlist) {
    unawaited(HapticFeedback.selectionClick());
    final id = (playlist['ytid'] ?? playlist['playlistId'] ?? '').toString();
    if (id.isEmpty) return;
    context.push(
      playlist['isAlbum'] == true
          ? NavigationPaths.albumPath(context, id)
          : NavigationPaths.playlistPath(context, id),
      extra: playlist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);

    return CupertinoPageScaffold(
      backgroundColor: musynCanvas(isDark),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            leading: Navigator.canPop(context)
                ? CupertinoNavigationBarBackButton(
                    color: CupertinoTheme.of(context).primaryColor,
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
            largeTitle: const Text(
              'Top Charts',
              style: TextStyle(
                fontFamily: MusynStyle.displayFont,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            border: null,
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          if (offlineMode.value)
            SliverToBoxAdapter(
              child: ContentState(
                icon: CupertinoIcons.wifi_slash,
                title: 'Charts need an active connection',
                message: 'Your downloaded music is ready to play offline in the library.',
                actionLabel: 'Open downloads',
                onAction: () => context.go('/library/userSongs/offline'),
              ),
            )
          else ...[
            if (jiosaavnEnabled.value)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: musynElevatedSurface(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x1FFFFFFF)
                            : const Color(0x0A000000),
                        width: 0.5,
                      ),
                    ),
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: _provider,
                      children: {
                        'youtube': const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.play_rectangle_fill,
                                size: 14,
                                color: Color(0xFFFF0033),
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'YouTube Music',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: MusynStyle.uiFont,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        'jiosaavn': const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.waveform,
                                size: 14,
                                color: CupertinoColors.systemGreen,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'JioSaavn',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: MusynStyle.uiFont,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      },
                      onValueChanged: (value) {
                        if (value != null && value != _provider) {
                          HapticFeedback.selectionClick();
                          setState(() => _provider = value);
                        }
                      },
                    ),
                  ),
                ),
              ),
            if (_errors.contains(_provider))
              SliverToBoxAdapter(
                child: ContentState(
                  title: 'Charts could not be refreshed',
                  message:
                      'Check your connection and try again. Any cached chart is shown below.',
                  actionLabel: 'Retry charts',
                  onAction: _load,
                ),
              ),
            if (_loading)
              const SliverToBoxAdapter(
                child: ContentState(
                  loading: true,
                  title: 'Loading top charts',
                  message: 'Curating popular charts from the streaming catalogue.',
                ),
              ),
            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable:
                  _provider == 'youtube' ? ytChartPlaylists : saavnCharts,
              builder: (context, rawItems, _) {
                final usable = rawItems
                    .where(
                      (item) =>
                          (item['ytid'] ?? item['playlistId'] ?? '')
                              .toString()
                              .isNotEmpty,
                    )
                    .toList();

                if (usable.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }

                final featured = usable.first;
                final remaining = usable.length > 1 ? usable.sublist(1) : <Map<String, dynamic>>[];

                return SliverMainAxisGroup(
                  slivers: [
                    // Featured #1 Top Chart Banner
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                        child: _buildFeaturedCard(context, featured, isDark),
                      ),
                    ),
                    if (remaining.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                          child: Text(
                            'Rankings & Collections',
                            style: TextStyle(
                              fontFamily: MusynStyle.displayFont,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? CupertinoColors.white
                                  : CupertinoColors.black,
                            ),
                          ),
                        ),
                      ),
                      _buildGridSliver(context, remaining, isDark),
                    ],
                  ],
                );
              },
            ),
          ],
          const SliverMiniPlayerBottomSpace(),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    Map<String, dynamic> playlist,
    bool isDark,
  ) {
    final title = playlist['title']?.toString() ?? 'Top 100';
    final subtitle = playlist['subtitle']?.toString() ??
        (_provider == 'youtube' ? 'YouTube Music Top Chart' : 'JioSaavn Weekly Chart');
    final artworkUrl = playlist['image']?.toString();
    final id = (playlist['ytid'] ?? playlist['playlistId'] ?? '').toString();

    return GestureDetector(
      onTap: () => _openPlaylist(context, playlist),
      onLongPress: () => PlaylistBar(
        title,
        playlistId: id,
        playlistArtwork: artworkUrl,
        playlistData: {...playlist, 'ytid': id},
      ).showActions(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: musynElevatedSurface(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x38000000) : const Color(0x0F000000),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Subtle gradient background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0x28FF2D55),
                              const Color(0x121A1A1E),
                            ]
                          : [
                              const Color(0x1FFF2D55),
                              const Color(0xFFF7F7F8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Artwork Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: PlaylistArtwork(
                          playlistArtwork: artworkUrl,
                          size: 96,
                          cubeIcon: CupertinoIcons.flame_fill,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MusynStyle.appleRed.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.flame_fill,
                                  size: 11,
                                  color: MusynStyle.appleRed,
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'FEATURED CHART',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: MusynStyle.uiFont,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: MusynStyle.appleRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: MusynStyle.displayFont,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? CupertinoColors.white
                                  : CupertinoColors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
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
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: MusynStyle.appleRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.play_fill,
                          color: CupertinoColors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridSliver(
    BuildContext context,
    List<Map<String, dynamic>> items,
    bool isDark,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverLayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = scale > 1.3 ? 1 : (box.crossAxisExtent > 600 ? 3 : 2);
          final width = (box.crossAxisExtent - (columns - 1) * 14) / columns;

          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              mainAxisExtent: width + 68 * scale,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final playlist = items[index];
              final title = playlist['title']?.toString() ?? 'Chart';
              final subtitle = playlist['subtitle']?.toString() ?? '';
              final id =
                  (playlist['ytid'] ?? playlist['playlistId'] ?? '').toString();
              final artworkUrl = playlist['image']?.toString();

              return GestureDetector(
                onTap: () => _openPlaylist(context, playlist),
                onLongPress: () => PlaylistBar(
                  title,
                  playlistId: id,
                  playlistArtwork: artworkUrl,
                  playlistData: {...playlist, 'ytid': id},
                ).showActions(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Artwork
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? const Color(0x28000000)
                                : const Color(0x0A000000),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: PlaylistArtwork(
                            playlistArtwork: artworkUrl,
                            size: width,
                            cubeIcon: CupertinoIcons.music_albums,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: MusynStyle.displayFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isDark
                            ? CupertinoColors.white
                            : CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.isNotEmpty ? subtitle : 'Playlist',
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
              );
            },
          );
        },
      ),
    );
  }
}
