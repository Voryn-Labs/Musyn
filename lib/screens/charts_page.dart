import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/discovery_state.dart';
import 'package:musyn/services/jiosaavn_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_collection_grid.dart';

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
          if (items.isNotEmpty)
            target.value = items;
          else
            _errors.add(provider);
        });
      } catch (_) {
        if (mounted && request == _request)
          setState(() => _errors.add(provider));
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

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: musynCanvas(isAppDarkMode(context)),
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        const CupertinoSliverNavigationBar(
          largeTitle: Text('Charts'),
          border: null,
        ),
        CupertinoSliverRefreshControl(onRefresh: _load),
        if (offlineMode.value)
          SliverToBoxAdapter(
            child: ContentState(
              icon: CupertinoIcons.wifi_slash,
              title: 'Charts need a connection',
              message: 'Your downloaded music is available in the library.',
              actionLabel: 'Open downloads',
              onAction: () => context.go('/library/userSongs/offline'),
            ),
          )
        else ...[
          if (jiosaavnEnabled.value)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: _provider,
                  children: const {
                    'youtube': Text('YouTube Music'),
                    'jiosaavn': Text('JioSaavn'),
                  },
                  onValueChanged: (value) {
                    if (value != null) setState(() => _provider = value);
                  },
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _provider == 'youtube'
                    ? 'YouTube Music charts'
                    : 'JioSaavn charts',
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ),
          if (_errors.contains(_provider))
            SliverToBoxAdapter(
              child: ContentState(
                title: 'Charts could not be refreshed',
                message:
                    'Check your connection and try again. Any saved chart list is shown below.',
                actionLabel: 'Retry charts',
                onAction: _load,
              ),
            ),
          if (_loading)
            const SliverToBoxAdapter(
              child: ContentState(
                loading: true,
                title: 'Loading charts',
                message:
                    'Getting chart playlists from the selected catalogues.',
              ),
            ),
          ValueListenableBuilder(
            valueListenable: _provider == 'youtube'
                ? ytChartPlaylists
                : saavnCharts,
            builder: (context, items, _) =>
                items.isEmpty && (_loading || _errors.contains(_provider))
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : PlaylistCollectionGrid(items: items),
          ),
        ],
        const SliverMiniPlayerBottomSpace(),
      ],
    ),
  );
}
