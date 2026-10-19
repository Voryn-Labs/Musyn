import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/widgets/account_button.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_collection_grid.dart';

/// Explore follows the catalogue's actual browse destinations and playlist IDs.
class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    this.category,
    this.loadCategories,
    this.loadCollections,
  });
  final Future<List<Map<String, dynamic>>> Function()? loadCategories;
  final Map<String, dynamic>? category;
  final Future<List<Map<String, dynamic>>> Function(String, String?)?
  loadCollections;
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;
  bool _failed = false;
  int _request = 0;
  final _service = YouTubeMusicSyncService();

  @override
  void initState() {
    super.initState();
    offlineMode.addListener(_modeChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    offlineMode.removeListener(_modeChanged);
    super.dispose();
  }

  void _modeChanged() {
    unawaited(_load());
  }

  @override
  void didUpdateWidget(ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category?['browseId'] != widget.category?['browseId'] ||
        oldWidget.category?['params'] != widget.category?['params'])
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
      _failed = false;
    });
    try {
      if (widget.category case final category?) {
        final id = category['browseId']?.toString() ?? '';
        if (id.isEmpty)
          throw const FormatException('Missing category destination');
        final items =
            await (widget.loadCollections?.call(
                      id,
                      category['params']?.toString(),
                    ) ??
                    _service.fetchExploreCollections(
                      id,
                      params: category['params']?.toString(),
                    ))
                .timeout(const Duration(seconds: 15));
        if (mounted && request == _request)
          setState(() => _collections = items);
      } else {
        final items =
            await (widget.loadCategories?.call() ??
                    _service.fetchMoodCategories())
                .timeout(const Duration(seconds: 15));
        if (mounted && request == _request)
          setState(
            () => _categories = items
                .where(
                  (item) =>
                      (item['browseId']?.toString() ?? '').isNotEmpty &&
                      (item['title']?.toString() ?? '').isNotEmpty,
                )
                .toList(),
          );
      }
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isAppDarkMode(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    return CupertinoPageScaffold(
      backgroundColor: musynCanvas(dark),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              widget.category?['title']?.toString() ?? 'Explore',
            ),
            trailing: const AccountButton(),
            border: null,
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          if (offlineMode.value)
            SliverToBoxAdapter(
              child: ContentState(
                icon: CupertinoIcons.wifi_slash,
                title: 'Explore needs a connection',
                message: 'Listen to your downloaded music while offline.',
                actionLabel: 'Open downloads',
                onAction: () => context.go('/library/userSongs/offline'),
              ),
            )
          else if (widget.category == null) ...[
            if (_categories.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: largeText ? 1 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.72,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    // Stable tones, while labels and browse endpoints come from the service.
                    const colors = [
                      Color(0xFF74513F),
                      Color(0xFF476C72),
                      Color(0xFF625582),
                      Color(0xFF41614F),
                      Color(0xFF8B4B56),
                      Color(0xFF836A36),
                    ];
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => context.push(
                        Uri(
                          path: '/explore/category',
                          queryParameters: {
                            'id': category['browseId'].toString(),
                            if (category['params'] != null)
                              'params': category['params'].toString(),
                            'title': category['title'].toString(),
                          },
                        ).toString(),
                        extra: category,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: colors[index % colors.length]),
                            Positioned(
                              right: 12,
                              bottom: 10,
                              child: Icon(
                                CupertinoIcons.music_note_2,
                                color: CupertinoColors.white.withValues(
                                  alpha: .16,
                                ),
                                size: 40,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Text(
                                category['title'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ] else if (_collections.isNotEmpty)
            PlaylistCollectionGrid(items: _collections),
          if (_loading && !offlineMode.value)
            const SliverToBoxAdapter(
              child: ContentState(
                loading: true,
                title: 'Loading catalogue',
                message: 'Finding moods, genres and playlists.',
              ),
            ),
          if (!_loading &&
              !offlineMode.value &&
              (_failed ||
                  (widget.category != null
                      ? _collections.isEmpty
                      : _categories.isEmpty)))
            SliverToBoxAdapter(
              child: ContentState(
                title: _failed
                    ? 'Catalogue unavailable'
                    : 'No collections available yet',
                message: 'Refresh this catalogue or find music through search.',
                actionLabel: 'Retry catalogue',
                onAction: _load,
                secondaryLabel: widget.category == null
                    ? 'Browse charts'
                    : 'Search this category',
                onSecondary: () => widget.category == null
                    ? context.push(NavigationPaths.chartsPath(context))
                    : context.go(
                        Uri(
                          path: '/search',
                          queryParameters: {
                            'q': widget.category?['title']?.toString() ?? '',
                          },
                        ).toString(),
                      ),
              ),
            ),
          const SliverMiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}
