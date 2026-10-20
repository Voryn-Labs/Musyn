import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/discovery_state.dart';
import 'package:musyn/services/jiosaavn_service.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_artwork.dart';

class ChartsPage extends StatefulWidget {
  const ChartsPage({
    super.key,
    this.loadYoutube,
    this.loadSaavn,
    this.playChart,
  });
  final Future<List<Map<String, dynamic>>> Function()? loadYoutube;
  final Future<List<Map<String, dynamic>>> Function()? loadSaavn;
  final Future<void> Function(Map<String, dynamic>)? playChart;
  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  String _provider = 'youtube';
  bool _loading = true;
  String? _playingChart, _playError;
  final _errors = <String>{};
  int _request = 0;
  @override
  void initState() {
    super.initState();
    offlineMode.addListener(_modeChanged);
    jiosaavnEnabled.addListener(_modeChanged);
    chartCountry.addListener(_regionChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    offlineMode.removeListener(_modeChanged);
    jiosaavnEnabled.removeListener(_modeChanged);
    chartCountry.removeListener(_regionChanged);
    super.dispose();
  }

  void _modeChanged() {
    if (!jiosaavnAvailable) _provider = 'youtube';
    unawaited(_load());
  }

  void _regionChanged() {
    // Cached charts from another region must never appear under the new label.
    ytChartPlaylists.value = [];
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    if (offlineMode.value) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _errors.clear();
      _playError = null;
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
        if (mounted && request == _request)
          setState(() => _errors.add(provider));
      }
    }

    await Future.wait([
      section(
        'youtube',
        widget.loadYoutube ??
            () => YouTubeMusicSyncService().fetchChartPlaylists(),
        ytChartPlaylists,
      ),
      if (jiosaavnAvailable)
        section(
          'jiosaavn',
          widget.loadSaavn ?? () => JioSaavnService().fetchTopCharts(limit: 20),
          saavnCharts,
        ),
    ]);
    if (mounted && request == _request) setState(() => _loading = false);
  }

  void _open(Map<String, dynamic> chart) {
    final id = (chart['ytid'] ?? chart['playlistId'] ?? '').toString();
    if (id.isEmpty) return;
    context.push(NavigationPaths.playlistPath(context, id), extra: chart);
  }

  Future<void> _play(Map<String, dynamic> chart) async {
    if (_playingChart != null) return;
    final id = (chart['ytid'] ?? chart['playlistId']).toString();
    setState(() {
      _playingChart = id;
      _playError = null;
    });
    try {
      if (widget.playChart != null) {
        await widget.playChart!(chart);
      } else {
        final saavn =
            chart['catalogOrigin'] == 'saavn' || chart['source'] == 'saavn';
        final List<Map> tracks;
        if (saavn) {
          final detail = await JioSaavnService().fetchPlaylistDetails(id);
          tracks = List<Map>.from(detail?['list'] ?? []);
        } else {
          tracks = await YouTubeMusicSyncService().fetchPlaylistTracks(id);
        }
        // Do not replace the queue if a delayed request outlives this page.
        if (!mounted) return;
        if (tracks.isEmpty) throw StateError('Empty chart');
        await audioHandler.playPlaylistSong(
          playlist: {...chart, 'list': tracks},
          songIndex: 0,
        );
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _playError =
              'Could not play this chart. Open it or try Play again.',
        );
    } finally {
      if (mounted) setState(() => _playingChart = null);
    }
  }

  void _chooseCountry() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Chart country'),
        message: const Text(
          'Applies to YouTube Music. JioSaavn charts use its own catalogue.',
        ),
        actions: [
          for (final entry in chartCountries.entries)
            CupertinoActionSheetAction(
              isDefaultAction: chartCountry.value == entry.key,
              onPressed: () {
                Navigator.pop(sheetContext);
                chartCountry.value = entry.key;
                unawaited(
                  addOrUpdateData('settings', 'chartCountry', entry.key),
                );
              },
              child: Text(entry.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isAppDarkMode(context);
    return CupertinoPageScaffold(
      backgroundColor: musynCanvas(dark),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Top Charts'),
            border: null,
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          if (offlineMode.value)
            SliverToBoxAdapter(
              child: ContentState(
                icon: CupertinoIcons.wifi_slash,
                title: 'Charts need an active connection',
                message: 'Your downloaded music is ready in the library.',
                actionLabel: 'Open downloads',
                onAction: () => context.go('/library/userSongs/offline'),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (jiosaavnAvailable)
                      CupertinoSlidingSegmentedControl<String>(
                        groupValue: _provider,
                        children: const {
                          'youtube': Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'YouTube Music',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          'jiosaavn': Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'JioSaavn',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value != null) setState(() => _provider = value);
                        },
                      ),
                    if (_provider == 'youtube')
                      CupertinoButton(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        onPressed: _chooseCountry,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.globe, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              chartCountries[chartCountry.value] ?? 'India',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(width: 6),
                            const Icon(CupertinoIcons.chevron_down, size: 12),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_errors.contains(_provider))
              SliverToBoxAdapter(
                child: ContentState(
                  title: 'Charts could not be refreshed',
                  message:
                      'Check your connection. Previously loaded charts remain below.',
                  actionLabel: 'Retry charts',
                  onAction: _load,
                ),
              ),
            if (_playError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_playError!),
                ),
              ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              ),
            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _provider == 'youtube'
                  ? ytChartPlaylists
                  : saavnCharts,
              builder: (context, items, _) {
                final usable = items
                    .where(
                      (c) =>
                          (c['ytid'] ?? c['playlistId'] ?? '')
                              .toString()
                              .isNotEmpty &&
                          (_provider != 'youtube' ||
                              c['chartCountry'] == null ||
                              c['chartCountry'] == chartCountry.value),
                    )
                    .toList();
                final groups = <String, List<Map<String, dynamic>>>{};
                for (final chart in usable) {
                  final title = _provider == 'jiosaavn'
                      ? 'JioSaavn charts'
                      : switch (chart['chartGroup']) {
                          'songs' => 'Song charts',
                          'videos' => 'Music-video charts',
                          'trending' => 'Trending charts',
                          'languages' => 'By language',
                          _ => 'Chart collections',
                        };
                  groups.putIfAbsent(title, () => []).add(chart);
                }
                return SliverList.list(
                  children: [
                    if (_provider == 'youtube' &&
                        !_loading &&
                        !_errors.contains('youtube') &&
                        !usable.any((c) => c['chartGroup'] == 'songs'))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Text(
                          'YouTube is offering music-video charts here. A song chart is not currently available for this country.',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ),
                    for (final group in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          group.key,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final chart in group.value) _row(chart, dark),
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

  Widget _row(Map<String, dynamic> chart, bool dark) {
    final title = chart['title']?.toString() ?? 'Chart';
    final id = (chart['ytid'] ?? chart['playlistId']).toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: musynElevatedSurface(dark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.all(12),
                onPressed: () => _open(chart),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: PlaylistArtwork(
                        playlistArtwork: chart['image']?.toString(),
                        size: 64,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open chart',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
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
            CupertinoButton(
              padding: const EdgeInsets.all(12),
              onPressed: _playingChart == null ? () => _play(chart) : null,
              child: _playingChart == id
                  ? const CupertinoActivityIndicator()
                  : Semantics(
                      label: 'Play $title',
                      child: const Icon(
                        CupertinoIcons.play_circle_fill,
                        size: 32,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
