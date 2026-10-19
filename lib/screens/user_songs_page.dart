import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/constants/app_constants.dart';
import 'package:musyn/models/playlist_sort_type.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/library_ranking.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/player_drawer.dart';
import 'package:musyn/widgets/playlist_cube.dart';
import 'package:musyn/widgets/playlist_page/playlist_action_buttons.dart';
import 'package:musyn/widgets/playlist_page/playlist_header.dart';
import 'package:musyn/widgets/song_tile.dart';

class UserSongsPage extends StatefulWidget {
  const UserSongsPage({super.key, required this.page});

  final String page;

  @override
  State<UserSongsPage> createState() => _UserSongsPageState();
}

class _UserSongsPageState extends State<UserSongsPage> {
  List _getDisplayList(List songsList) {
    if (widget.page == 'mostPlayed') return mostPlayedTracks(songsList);
    var list = List.from(songsList);
    if (widget.page == 'offline') {
      list = _sortOfflineSongsLocal(list, _getCurrentOfflineSortType());
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (!const {
      'liked',
      'offline',
      'recents',
      'mostPlayed',
    }.contains(widget.page)) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Collection unavailable'),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ContentState(
              title: 'Collection unavailable',
              message: 'Open your library to choose a saved collection.',
              actionLabel: 'Open library',
              onAction: () => context.go('/library'),
            ),
          ),
        ),
      );
    }
    final title = getTitle(widget.page, context);
    final icon = getIcon(widget.page);
    final isOfflineSongs = widget.page == 'offline';
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark
        ? const Color(0xB3121214)
        : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF),
      navigationBar: CupertinoNavigationBar(
        trailing: isOfflineSongs
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showSort,
                child: const Icon(
                  CupertinoIcons.sort_down,
                  semanticLabel: 'Sort downloads',
                ),
              )
            : null,
        middle: Text(
          title,
          style: const TextStyle(
            fontFamily: MusynStyle.displayFont,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: navBarColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: commonSingleChildScrollViewPadding,
          child: ValueListenableBuilder<List>(
            valueListenable: widget.page == 'liked'
                ? userLikedSongsList
                : widget.page == 'offline'
                ? userOfflineSongs
                : userRecentlyPlayed,
            builder: (_, songsList, __) => _buildCustomScrollView(
              title,
              icon,
              _getDisplayList(songsList).length,
              isOfflineSongs,
              isDark,
            ),
          ),
        ),
      ),
    );
  }

  OfflineSortType _getCurrentOfflineSortType() {
    return OfflineSortType.values.firstWhere(
      (e) => e.name == offlineSortSetting,
      orElse: () => OfflineSortType.default_,
    );
  }

  Widget _buildCustomScrollView(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
    bool isDark,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeaderSection(
            title,
            icon,
            songsLength,
            isOfflineSongs,
            isDark,
          ),
        ),
        buildSongList(title),
        const SliverMiniPlayerBottomSpace(),
      ],
    );
  }

  String getTitle(String page, BuildContext context) {
    return switch (page) {
      'liked' => 'Liked Music',
      'offline' => 'Downloaded Songs',
      'recents' => 'Recently Played',
      'mostPlayed' => 'Most Played',
      _ => 'Playlist',
    };
  }

  IconData getIcon(String page) {
    return switch (page) {
      'liked' => CupertinoIcons.heart_fill,
      'offline' => CupertinoIcons.arrow_down_circle_fill,
      'recents' => CupertinoIcons.clock_fill,
      'mostPlayed' => CupertinoIcons.chart_bar_fill,
      _ => CupertinoIcons.heart_fill,
    };
  }

  Widget _buildHeaderSection(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
    bool isDark,
  ) {
    final isRecentlyPlayed = widget.page == 'recents';

    return Column(
      children: [
        PlaylistHeader(
          _buildPlaylistImage(title, icon),
          title,
          songsLength: songsLength,
          showTitle: false,
        ),
        if (songsLength > 0) ...[
          PlaylistActionButtons(
            onPlay: () {
              final songsList = widget.page == 'liked'
                  ? userLikedSongsList.value
                  : widget.page == 'offline'
                  ? userOfflineSongs.value
                  : userRecentlyPlayed.value;
              final sortedList = _getDisplayList(songsList);
              final playlist = {
                'ytid': '',
                'title': title,
                'source': 'user-created',
                'list': sortedList,
              };
              audioHandler.playPlaylistSong(playlist: playlist, songIndex: 0);
            },
            onShuffle: () async {
              final songs = widget.page == 'liked'
                  ? userLikedSongsList.value
                  : widget.page == 'offline'
                  ? userOfflineSongs.value
                  : userRecentlyPlayed.value;
              if (songs.isEmpty) return;
              final shuffled = List<Map>.from(
                _getDisplayList(songs).whereType<Map>(),
              )..shuffle();
              await audioHandler.addPlaylistToQueue(
                shuffled,
                replace: true,
                startIndex: 0,
                resetShuffle: false,
              );
            },
          ),
          if (isRecentlyPlayed) ...[
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                await deleteData('user', 'recentlyPlayed');
                userRecentlyPlayed.value = [];
                if (mounted) showToast(context, 'History cleared');
              },
              child: const Text(
                'Clear History',
                style: TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPlaylistImage(String title, IconData icon) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    return PlaylistCube(
      {'title': title},
      size: isLandscape ? 250 : screenWidth / commonPlaylistArtworkDivision,
      cubeIcon: icon,
      showTypeLabel: false,
    );
  }

  Widget buildSongList(String title) {
    final isLikedSongs = widget.page == 'liked';
    final isRecentSongs = widget.page == 'recents';

    return ValueListenableBuilder<List>(
      valueListenable: isLikedSongs
          ? userLikedSongsList
          : widget.page == 'offline'
          ? userOfflineSongs
          : userRecentlyPlayed,
      builder: (context, rawSongs, _) {
        final songs = _getDisplayList(rawSongs);
        if (songs.isEmpty) {
          return SliverToBoxAdapter(
            child: ContentState(
              icon: getIcon(widget.page),
              title: widget.page == 'offline'
                  ? 'No downloads yet'
                  : widget.page == 'liked'
                  ? 'Your favorites belong here'
                  : 'Your listening starts here',
              message: widget.page == 'offline'
                  ? 'Download tracks from their options menu to listen without a connection.'
                  : widget.page == 'liked'
                  ? 'Tap the heart on a track to save it to Liked Music.'
                  : 'Play music to build your listening history and most-played collection.',
              actionLabel: offlineMode.value
                  ? 'Go online to find music'
                  : 'Find music',
              onAction: _findMusic,
            ),
          );
        }

        final playlist = {
          'ytid': '',
          'title': title,
          'source': 'user-created',
          'list': songs,
        };

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = songs[index] as Map;
            return SongTile(
              song: song,
              key: ValueKey('user_song_${song['ytid']}_$index'),
              isRecent: isRecentSongs,
              onTap: () {
                HapticFeedback.selectionClick();
                audioHandler.playPlaylistSong(
                  playlist: playlist,
                  songIndex: index,
                );
              },
            );
          }, childCount: songs.length),
        );
      },
    );
  }

  void _findMusic() {
    if (offlineMode.value) {
      offlineMode.value = false;
      unawaited(addOrUpdateData('settings', 'offlineMode', false));
    }
    context.go('/search');
  }

  void _showSort() {
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.50),
      builder: (sheet) => PlayerDrawer(
        title: 'Sort Downloaded Tracks',
        subtitle: 'Choose how your offline tracks are organized',
        trailingHeader: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          onPressed: () => Navigator.pop(sheet),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: MusynStyle.uiFont,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MusynStyle.appleRed,
            ),
          ),
        ),
        children: [
          for (final type in OfflineSortType.values)
            PlayerDrawerRow(
              title: switch (type) {
                OfflineSortType.default_ => 'Default order',
                OfflineSortType.title => 'Title',
                OfflineSortType.artist => 'Artist',
                OfflineSortType.dateAdded => 'Newest first',
              },
              subtitle: type == _getCurrentOfflineSortType()
                  ? 'Currently selected sorting order'
                  : '',
              icon: switch (type) {
                OfflineSortType.default_ => CupertinoIcons.list_bullet,
                OfflineSortType.title => CupertinoIcons.textformat,
                OfflineSortType.artist => CupertinoIcons.person_2,
                OfflineSortType.dateAdded => CupertinoIcons.time,
              },
              iconBg: type == _getCurrentOfflineSortType()
                  ? MusynStyle.appleRed
                  : CupertinoColors.systemGrey,
              selected: type == _getCurrentOfflineSortType(),
              onTap: () {
                Navigator.pop(sheet);
                setState(() => offlineSortSetting = type.name);
                unawaited(
                  addOrUpdateData('settings', 'offlineSortType', type.name),
                );
              },
            ),
        ],
      ),
    );
  }

  List _sortOfflineSongsLocal(List list, OfflineSortType type) {
    final sortedList = List<dynamic>.from(list);
    switch (type) {
      case OfflineSortType.default_:
        return sortedList;
      case OfflineSortType.title:
        sortedList.sort((a, b) {
          final titleA = (a['title'] ?? '').toString().toLowerCase();
          final titleB = (b['title'] ?? '').toString().toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
      case OfflineSortType.artist:
        sortedList.sort((a, b) {
          final artistA = (a['artist'] ?? '').toString().toLowerCase();
          final artistB = (b['artist'] ?? '').toString().toLowerCase();
          return artistA.compareTo(artistB);
        });
        break;
      case OfflineSortType.dateAdded:
        sortedList.sort((a, b) {
          final dateA = a['dateAdded'] as int? ?? 0;
          final dateB = b['dateAdded'] as int? ?? 0;
          return dateB.compareTo(dateA);
        });
        break;
    }
    return sortedList;
  }
}
