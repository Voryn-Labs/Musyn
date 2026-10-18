import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musified/constants/browse_categories.dart';
import 'package:musified/services/audio/audio_runtime.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/logger_service.dart';
import 'package:musified/services/navigation_paths.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/artist_bar.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';
import 'package:musified/widgets/playlist_bar.dart';
import 'package:musified/widgets/section_header.dart';
import 'package:musified/widgets/song_actions_sheet.dart';
import 'package:musified/widgets/song_tile.dart';

final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>([]);

enum _SearchFilter { all, songs, artists, playlists }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  bool _isSearching = false;
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
    if (searchHistoryNotifier.value.isEmpty) {
      searchHistoryNotifier.value = Hive.box(
        'user',
      ).get('searchHistory', defaultValue: <dynamic>[]);
    }
  }

  @override
  void dispose() {
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
        }
      }

      await Future.wait([
        load(
          () => fetchSongsList(query),
          (value) => _songsSearchResult = value as List,
        ),
        load(
          () => searchArtists(query),
          (value) => _artistsSearchResult = List<Map<String, dynamic>>.from(
            value as List,
          ),
        ),
        load(
          () => getPlaylists(query: query),
          (value) => _playlistsSearchResult = value as List,
        ),
      ]);
      if (mounted && requestId == _latestSearchRequest) {
        setState(() => _isSearching = false);
      }
    } catch (e) {
      logger.log('Search error: $e');
      if (mounted && requestId == _latestSearchRequest) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _onQueryChanged(String query) {
    ++_latestSearchRequest;
    _isSearching = false;
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

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final trimmed = _searchBar.text.trim();
      if (trimmed.isEmpty) return;
      try {
        final suggestions = await getSearchSuggestions(trimmed);
        if (!mounted || _searchBar.text.trim() != trimmed) return;
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
    final navBarColor = isDark
        ? const Color(0xB3121214)
        : const Color(0xB3FFFFFF);
    final hasResults =
        _songsSearchResult.isNotEmpty ||
        _artistsSearchResult.isNotEmpty ||
        _playlistsSearchResult.isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: musifiedCanvas(isDark),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'Search',
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchBar,
                focusNode: _inputNode,
                placeholder: 'Artists, songs, or playlists',
                onChanged: _onQueryChanged,
                onSubmitted: _submitSearch,
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
            ),
          ),
          if (hasResults && !_isSearching)
            SliverToBoxAdapter(
              child: _buildFilterTabs(isDark),
            ),
          if (_isSearching && !hasResults)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CupertinoActivityIndicator(radius: 12)),
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
                      fontFamily: MusifiedStyle.uiFont,
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
              ? MusifiedStyle.appleRed
              : musifiedElevatedSurface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? MusifiedStyle.appleRed
                : (isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000)),
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: MusifiedStyle.uiFont,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? CupertinoColors.white
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
            const SizedBox(height: 18),
            const Text(
              'Explore Categories',
              style: TextStyle(
                fontFamily: MusifiedStyle.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Browse songs, charts, moods, and genres',
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 13,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.85,
              ),
              itemCount: defaultBrowseCategories.length,
              itemBuilder: (context, index) {
                final category = defaultBrowseCategories[index];
                return _BrowseCategoryCard(
                  category: category,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _submitSearch(category.searchQuery);
                  },
                );
              },
            ),
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
                    fontFamily: MusifiedStyle.displayFont,
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
                      color: MusifiedStyle.appleRed,
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
                  padding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    color: musifiedElevatedSurface(isDark),
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
                                fontFamily: MusifiedStyle.uiFont,
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

  Widget _buildTopResultCard(Map song, bool isDark) {
    final title = song['title']?.toString() ?? 'Track';
    final artist = song['artist']?.toString() ?? 'Artist';
    final image = song['highResImage'] ?? song['image'] ?? song['lowResImage'] ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      padding: const EdgeInsets.all(14),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: image.toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image.toString(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: musifiedSecondarySurface(isDark),
                        child: const Icon(CupertinoIcons.music_note, color: CupertinoColors.systemGrey),
                      ),
                    )
                  : ColoredBox(
                      color: musifiedSecondarySurface(isDark),
                      child: const Icon(CupertinoIcons.music_note, color: CupertinoColors.systemGrey),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: MusifiedStyle.appleRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TOP RESULT',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: MusifiedStyle.appleRed,
                      letterSpacing: 0.5,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(10),
            color: MusifiedStyle.appleRed,
            borderRadius: BorderRadius.circular(24),
            onPressed: () {
              HapticFeedback.selectionClick();
              audioHandler.playSingleSong(song);
            },
            child: const Icon(
              CupertinoIcons.play_fill,
              size: 20,
              color: CupertinoColors.white,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => showSongActionsSheet(context, song: song),
            child: const Icon(
              CupertinoIcons.ellipsis,
              size: 20,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredResults(bool isDark) {
    final showSongs = _currentFilter == _SearchFilter.all || _currentFilter == _SearchFilter.songs;
    final showArtists = _currentFilter == _SearchFilter.all || _currentFilter == _SearchFilter.artists;
    final showPlaylists = _currentFilter == _SearchFilter.all || _currentFilter == _SearchFilter.playlists;

    final topSong = _currentFilter == _SearchFilter.all && _songsSearchResult.isNotEmpty
        ? (_songsSearchResult.first is Map ? _songsSearchResult.first as Map : null)
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
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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

class _BrowseCategoryCard extends StatelessWidget {
  const _BrowseCategoryCard({
    required this.category,
    required this.onTap,
  });

  final BrowseCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: category.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: category.gradientColors.first.withValues(alpha: 0.28),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: -6,
              child: Icon(
                category.icon,
                size: 40,
                color: CupertinoColors.white.withValues(alpha: 0.22),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                category.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: MusifiedStyle.displayFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
