import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musyn/services/app_navigation_state.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/discovery_state.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/widgets/account_button.dart';
import 'package:musyn/widgets/artist_bar.dart';
import 'package:musyn/widgets/catalogue_artwork.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/discovery_links.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_bar.dart';
import 'package:musyn/widgets/section_header.dart';
import 'package:musyn/widgets/song_actions_sheet.dart';
import 'package:musyn/widgets/song_tile.dart';

export 'package:musyn/services/discovery_state.dart' show searchHistoryNotifier;

enum _SearchFilter { all, songs, artists, playlists }

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery,
    this.loadSongs,
    this.loadArtists,
    this.loadPlaylists,
    this.loadSuggestions,
  });
  final Future<List> Function(String)? loadSongs;
  final Future<List<Map<String, dynamic>>> Function(String)? loadArtists;
  final Future<List> Function(String)? loadPlaylists;
  final Future<List<String>> Function(String)? loadSuggestions;
  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  bool _isSearching = false;
  bool _submitted = false;
  final Set<String> _failedSections = {};
  _SearchFilter _currentFilter = _SearchFilter.all;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSearchRequest = 0;

  @override
  void initState() {
    super.initState();
    searchTabActivation.addListener(_activateSearch);
    if (widget.initialQuery != null) {
      _searchBar.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_submitSearch());
      });
    }
    if (searchHistoryNotifier.value.isEmpty && Hive.isBoxOpen('user')) {
      searchHistoryNotifier.value = Hive.box(
        'user',
      ).get('searchHistory', defaultValue: <dynamic>[]);
    }
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery &&
        widget.initialQuery != null) {
      _searchBar.text = widget.initialQuery!;
      unawaited(_submitSearch());
    }
  }

  @override
  void dispose() {
    searchTabActivation.removeListener(_activateSearch);
    _searchBar.dispose();
    _inputNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
    }
    _debounce?.cancel();
    _suggestionsList = [];
    _inputNode.unfocus();
    await _performSearch();
  }

  Future<void> _performSearch() async {
    final query = _searchBar.text.trim();
    final requestId = ++_latestSearchRequest;

    if (query.isEmpty) {
      setState(() {
        _songsSearchResult = [];
        _artistsSearchResult = [];
        _playlistsSearchResult = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _submitted = true;
      _failedSections.clear();
      _isSearching = true;
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _playlistsSearchResult = [];
    });

    try {
      final searchHistory = List.from(searchHistoryNotifier.value);
      if (!searchHistory.contains(query)) {
        searchHistory.insert(0, query);
        if (searchHistory.length > 20) searchHistory.removeLast();
        searchHistoryNotifier.value = searchHistory;
        unawaited(
          addOrUpdateData<List>('user', 'searchHistory', searchHistory),
        );
      }

      Future<void> load(
        String section,
        Future<dynamic> Function() fetch,
        void Function(dynamic) publish,
      ) async {
        try {
          final value = await fetch().timeout(const Duration(seconds: 15));
          if (mounted && requestId == _latestSearchRequest) {
            setState(() => publish(value));
          }
        } catch (e) {
          logger.log('Search section failed: $e');
          if (mounted && requestId == _latestSearchRequest)
            setState(() => _failedSections.add(section));
        }
      }

      await Future.wait([
        load(
          'Songs',
          () => (widget.loadSongs ?? fetchSongsList)(query),
          (value) => _songsSearchResult = value as List,
        ),
        load(
          'Artists',
          () => (widget.loadArtists ?? searchArtists)(query),
          (value) => _artistsSearchResult = List<Map<String, dynamic>>.from(
            value as List,
          ),
        ),
        load(
          'Playlists',
          () => widget.loadPlaylists?.call(query) ?? getPlaylists(query: query),
          (value) => _playlistsSearchResult = value as List,
        ),
      ]);
      if (mounted && requestId == _latestSearchRequest) {
        setState(() => _isSearching = false);
      }
    } catch (e) {
      logger.log('Search error: $e');
      if (mounted && requestId == _latestSearchRequest)
        _failedSections.add('Search');
      if (mounted && requestId == _latestSearchRequest) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _activateSearch() {
    _searchBar.clear();
    _onQueryChanged('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputNode.requestFocus();
    });
  }

  void _onQueryChanged(String query) {
    ++_latestSearchRequest;
    setState(() {
      _submitted = false;
      _failedSections.clear();
      _isSearching = false;
      _suggestionsList = [];
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _playlistsSearchResult = [];
    });
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestionsList = [];
        _isSearching = false;
        _songsSearchResult = [];
        _artistsSearchResult = [];
        _playlistsSearchResult = [];
      });
      return;
    }

    final request = _latestSearchRequest;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final trimmed = _searchBar.text.trim();
      if (trimmed.isEmpty) return;
      try {
        final suggestions =
            await (widget.loadSuggestions ?? getSearchSuggestions)(trimmed);
        if (!mounted ||
            request != _latestSearchRequest ||
            _submitted ||
            _searchBar.text.trim() != trimmed)
          return;
        setState(() {
          _suggestionsList = suggestions.take(8).toList();
        });
      } catch (e) {
        logger.log('Suggestion error: $e');
      }
    });
  }

  void _removeHistoryItem(dynamic query) {
    HapticFeedback.selectionClick();
    final updated = List.from(searchHistoryNotifier.value)..remove(query);
    searchHistoryNotifier.value = updated;
    unawaited(addOrUpdateData<List>('user', 'searchHistory', updated));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final hasResults =
        _songsSearchResult.isNotEmpty ||
        _artistsSearchResult.isNotEmpty ||
        _playlistsSearchResult.isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: musynCanvas(isDark),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search',
                      style: MusynStyle.largeTitle(
                        CupertinoTheme.of(context).textTheme.textStyle.color!,
                      ),
                    ),
                  ),
                  const AccountButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: CupertinoSearchTextField(
                controller: _searchBar,
                focusNode: _inputNode,
                placeholder: 'Artists, songs, or playlists',
                onChanged: _onQueryChanged,
                onSubmitted: _submitSearch,
              ),
            ),
            if (hasResults && _suggestionsList.isEmpty)
              _buildFilterTabs(isDark),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  if (_failedSections.isNotEmpty && hasResults)
                    SliverToBoxAdapter(
                      child: ContentState(
                        title: 'Some results could not load',
                        message:
                            '${_failedSections.join(', ')} could not be refreshed. Your available results are below.',
                        actionLabel: 'Retry search',
                        onAction: _submitSearch,
                      ),
                    ),
                  if (_isSearching && !hasResults)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CupertinoActivityIndicator(radius: 12),
                        ),
                      ),
                    )
                  else if (_suggestionsList.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final suggestion = _suggestionsList[index];
                        return CupertinoListTile(
                          leading: const Icon(
                            CupertinoIcons.search,
                            size: 18,
                            color: CupertinoColors.systemGrey,
                          ),
                          title: Text(
                            suggestion,
                            style: TextStyle(
                              fontFamily: MusynStyle.uiFont,
                              color: isDark
                                  ? CupertinoColors.white
                                  : CupertinoColors.black,
                            ),
                          ),
                          trailing: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              _searchBar.text = suggestion;
                              _onQueryChanged(suggestion);
                            },
                            child: const Icon(
                              CupertinoIcons.arrow_up_left,
                              size: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          onTap: () => _submitSearch(suggestion),
                        );
                      }, childCount: _suggestionsList.length),
                    )
                  else if (!hasResults && _searchBar.text.isEmpty)
                    _buildEmptyQueryContent(isDark)
                  else if (hasResults)
                    _buildFilteredResults(isDark)
                  else
                    SliverToBoxAdapter(
                      child: ContentState(
                        icon: _failedSections.isEmpty
                            ? CupertinoIcons.search
                            : CupertinoIcons.wifi_exclamationmark,
                        title: !_submitted
                            ? 'Ready to search'
                            : _failedSections.isNotEmpty
                            ? 'Search is unavailable'
                            : 'No matches found',
                        message: !_submitted
                            ? 'Press Search to find songs, artists and playlists for “${_searchBar.text.trim()}”.'
                            : _failedSections.isNotEmpty
                            ? 'Check your connection and try this search again.'
                            : 'Try a different title, artist or spelling.',
                        actionLabel: !_submitted
                            ? 'Search now'
                            : _failedSections.isNotEmpty
                            ? 'Retry search'
                            : 'Clear search',
                        onAction: !_submitted || _failedSections.isNotEmpty
                            ? _submitSearch
                            : () {
                                _searchBar.clear();
                                _onQueryChanged('');
                                _inputNode.requestFocus();
                              },
                      ),
                    ),
                  const SliverMiniPlayerBottomSpace(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            _buildFilterPill('All', _SearchFilter.all, isDark),
            const SizedBox(width: 8),
            _buildFilterPill('Songs', _SearchFilter.songs, isDark),
            const SizedBox(width: 8),
            _buildFilterPill('Artists', _SearchFilter.artists, isDark),
            const SizedBox(width: 8),
            _buildFilterPill('Playlists', _SearchFilter.playlists, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, _SearchFilter filter, bool isDark) {
    final isSelected = _currentFilter == filter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? CupertinoColors.white : CupertinoColors.black)
              : musynElevatedSurface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? CupertinoColors.white : CupertinoColors.black)
                : (isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000)),
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: MusynStyle.uiFont,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? CupertinoColors.black : CupertinoColors.white)
                : (isDark ? CupertinoColors.white : CupertinoColors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyQueryContent(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchHistory(isDark),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 20, 4, 6),
              child: Text(
                'Find your next favorite',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
              child: Text(
                'Search both catalogues, or browse below.',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            const DiscoveryLinks(),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHistory(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: searchHistoryNotifier,
      builder: (context, history, _) {
        if (history.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontFamily: MusynStyle.displayFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    searchHistoryNotifier.value = [];
                    unawaited(deleteData('user', 'searchHistory'));
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 14,
                      color: MusynStyle.appleRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history.map<Widget>((query) {
                return Container(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 6,
                    top: 4,
                    bottom: 4,
                  ),
                  decoration: BoxDecoration(
                    color: musynElevatedSurface(isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x33FFFFFF)
                          : const Color(0x1F000000),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _submitSearch(query.toString());
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.clock,
                              size: 13,
                              color: CupertinoColors.systemGrey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              query.toString(),
                              style: TextStyle(
                                fontFamily: MusynStyle.uiFont,
                                fontSize: 13,
                                color: isDark
                                    ? CupertinoColors.white
                                    : CupertinoColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(24, 24),
                        onPressed: () => _removeHistoryItem(query),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          size: 12,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopResultCard(Map song, bool isDark) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: musynElevatedSurface(isDark),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top result',
          style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: CatalogueArtwork(
                  imageUrl: (song['highResImage'] ?? song['image'] ?? '')
                      .toString(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song['title']?.toString() ?? 'Track',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MusynStyle.songTitle(
                      CupertinoTheme.of(context).textTheme.textStyle.color!,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song['artist']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CupertinoButton.filled(
                onPressed: () => audioHandler.playSingleSong(song),
                child: const Text('Play'),
              ),
            ),
            const SizedBox(width: 12),
            CupertinoButton(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.all(10),
              onPressed: () => showSongActionsSheet(context, song: song),
              child: Icon(
                CupertinoIcons.ellipsis,
                semanticLabel: 'Track options',
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildFilteredResults(bool isDark) {
    final showSongs =
        _currentFilter == _SearchFilter.all ||
        _currentFilter == _SearchFilter.songs;
    final showArtists =
        _currentFilter == _SearchFilter.all ||
        _currentFilter == _SearchFilter.artists;
    final showPlaylists =
        _currentFilter == _SearchFilter.all ||
        _currentFilter == _SearchFilter.playlists;

    final visible =
        (showSongs ? _songsSearchResult.length : 0) +
        (showArtists ? _artistsSearchResult.length : 0) +
        (showPlaylists ? _playlistsSearchResult.length : 0);
    if (visible == 0)
      return SliverToBoxAdapter(
        child: ContentState(
          title: 'No ${_currentFilter.name} in these results',
          message: 'Try All to see the other matches, or change your search.',
          actionLabel: 'Show all results',
          onAction: () => setState(() => _currentFilter = _SearchFilter.all),
        ),
      );

    final topSong =
        _currentFilter == _SearchFilter.all && _songsSearchResult.isNotEmpty
        ? (_songsSearchResult.first is Map
              ? _songsSearchResult.first as Map
              : null)
        : null;

    final regularSongs = topSong != null
        ? _songsSearchResult.skip(1).toList()
        : _songsSearchResult;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topSong != null) _buildTopResultCard(topSong, isDark),
            if (showSongs && regularSongs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SectionHeader(
                  title: 'Songs',
                  icon: CupertinoIcons.music_note_list,
                ),
              ),
              ...regularSongs.map(
                (s) => SongTile(
                  song: s is Map ? s : {},
                  onTap: () {
                    HapticFeedback.selectionClick();
                    audioHandler.playSingleSong(s is Map ? s : {});
                  },
                ),
              ),
            ],
            if (showArtists && _artistsSearchResult.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SectionHeader(
                  title: 'Artists',
                  icon: CupertinoIcons.person_2_fill,
                ),
              ),
              ..._artistsSearchResult.map(
                (a) => ArtistBar(
                  artist: a,
                  onTap: () {
                    if (a['ytid'] != null) {
                      context.push(
                        NavigationPaths.artistPath(
                          context,
                          a['ytid'].toString(),
                        ),
                        extra: a,
                      );
                    }
                  },
                ),
              ),
            ],
            if (showPlaylists && _playlistsSearchResult.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SectionHeader(
                  title: 'Playlists',
                  icon: CupertinoIcons.music_albums_fill,
                ),
              ),
              ..._playlistsSearchResult.map(
                (p) => PlaylistBar(
                  p['title']?.toString() ?? 'Playlist',
                  playlistData: p,
                ),
              ),
            ],
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }
}
