import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/constants/app_constants.dart';
import 'package:musyn/extensions/l10n.dart';
import 'package:musyn/models/playlist_sort_type.dart';
import 'package:musyn/services/artist_service.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/services/playlist_sharing.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/playlist_utils.dart';
import 'package:musyn/utilities/song_filtering.dart';
import 'package:musyn/utilities/sort_utils.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/edit_playlist_dialog.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/playlist_cube.dart';
import 'package:musyn/widgets/playlist_page/add_to_playlist_button.dart';
import 'package:musyn/widgets/playlist_page/download_button.dart';
import 'package:musyn/widgets/playlist_page/like_button.dart';
import 'package:musyn/widgets/playlist_page/playlist_action_buttons.dart';
import 'package:musyn/widgets/playlist_page/playlist_header.dart';
import 'package:musyn/widgets/song_tile.dart';
import 'package:musyn/widgets/sort_chips.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({
    super.key,
    this.playlistId,
    this.playlistData,
    this.cubeIcon = CupertinoIcons.list_bullet,
    this.isArtist = false,
    this.loadPlaylist,
  });

  final String? playlistId;
  final dynamic playlistData;
  final IconData cubeIcon;
  final bool isArtist;
  final Future<Map?> Function(String)? loadPlaylist;

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  dynamic _playlist;
  List<dynamic> _originalPlaylistList = []; // Keep original order separately

  bool _isInitializingPlaylist = true;
  bool _loadFailed = false;
  bool _syncing = false;
  int _loadRequest = 0;

  String? get _resolvedPlaylistId =>
      _playlist?['ytid']?.toString() ??
      widget.playlistData?['ytid']?.toString() ??
      widget.playlistId;

  // Sorting
  late PlaylistSortType _sortType = PlaylistSortType.values.firstWhere(
    (e) => e.name == playlistSortSetting,
    orElse: () => PlaylistSortType.default_,
  );

  // Search
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  List _getSourceList(String searchQuery) {
    final list = _playlist?['list'] as List? ?? [];
    return filterSongsByQuery(list, searchQuery);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _initializePlaylist();
  }

  @override
  void didUpdateWidget(covariant PlaylistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId =
        oldWidget.playlistData?['ytid']?.toString() ?? oldWidget.playlistId;
    final newId = widget.playlistData?['ytid']?.toString() ?? widget.playlistId;
    if (oldId != newId || oldWidget.isArtist != widget.isArtist) {
      _playlist = null;
      _syncing = false;
      _originalPlaylistList = [];
      _searchController.clear();
      _searchQueryNotifier.value = '';
      unawaited(_initializePlaylist());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializePlaylist() async {
    final request = ++_loadRequest;
    setState(() {
      _isInitializingPlaylist = true;
      _loadFailed = false;
    });
    try {
      final initial = widget.playlistData is Map
          ? Map<dynamic, dynamic>.from(widget.playlistData as Map)
          : null;
      final id = initial?['ytid']?.toString() ?? widget.playlistId ?? '';
      Map? loaded;
      final local =
          initial?['source'] == 'user-created' || initial?['isOffline'] == true;
      if (initial?['list'] is List &&
          ((initial!['list'] as List).isNotEmpty || local)) {
        loaded = initial;
      } else {
        if (id.isEmpty)
          throw const FormatException('Missing playlist destination');
        loaded =
            await (widget.loadPlaylist?.call(id) ??
                    getPlaylistInfoForWidget(
                      id,
                      isArtist: widget.isArtist,
                      artistName: initial?['title']?.toString(),
                      artistImage: initial?['image']?.toString(),
                      sourceSongId: initial?['sourceSongId']?.toString(),
                      sourceVideoAuthor: initial?['videoAuthor']?.toString(),
                      preferredVerified: initial?['isVerifiedArtist'] == true,
                    ))
                .timeout(const Duration(seconds: 20));
      }
      if (!mounted || request != _loadRequest) return;
      if (loaded == null ||
          loaded['list'] is! List ||
          loaded['catalogStatus'] == 'failed')
        throw StateError('Playlist unavailable');
      if ((loaded['list'] as List).isEmpty &&
          loaded['source'] != 'user-created' &&
          loaded['isOffline'] != true &&
          loaded['downloadedAt'] == null &&
          loaded['catalogStatus'] != 'complete') {
        throw StateError('No playable remote track list available');
      }
      _playlist = Map<dynamic, dynamic>.from(loaded);
      _originalPlaylistList = List<dynamic>.from(_playlist['list'] as List);
      _sortPlaylist(_sortType);
    } catch (error, stack) {
      logger.log('Playlist could not load', error: error, stackTrace: stack);
      if (mounted && request == _loadRequest) _loadFailed = true;
    } finally {
      if (mounted && request == _loadRequest)
        setState(() => _isInitializingPlaylist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark
        ? const Color(0xB3121214)
        : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: musynCanvas(isDark),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          _playlistTitle,
          style: const TextStyle(
            fontFamily: MusynStyle.displayFont,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
        child: _isInitializingPlaylist && _playlist == null
            ? const ContentState(
                loading: true,
                title: 'Opening collection',
                message: 'Loading the track list…',
              )
            : _playlist != null
            ? CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeaderSection()),
                  if (_loadFailed)
                    SliverToBoxAdapter(
                      child: ContentState(
                        title: 'Could not refresh this collection',
                        message:
                            'Your previously loaded tracks are still available.',
                        actionLabel: 'Retry collection',
                        onAction: _handleSyncPlaylist,
                      ),
                    ),
                  if ((_playlist['list'] as List? ?? const []).isNotEmpty) ...[
                    ValueListenableBuilder<String>(
                      valueListenable: _searchQueryNotifier,
                      builder: (context, searchQuery, _) {
                        final sourceList = _getSourceList(searchQuery);
                        if (sourceList.isEmpty)
                          return SliverToBoxAdapter(
                            child: ContentState(
                              icon: CupertinoIcons.search,
                              title: 'No tracks match this filter',
                              message:
                                  'Try another title or artist, or clear your filter.',
                              actionLabel: 'Clear filter',
                              onAction: () {
                                _searchController.clear();
                                _searchQueryNotifier.value = '';
                              },
                            ),
                          );
                        return SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final isRemovable =
                                _playlist['source'] == 'user-created';
                            return _buildSongListItem(
                              sourceList[index] as Map,
                              index,
                              isRemovable,
                              sourceList,
                            );
                          }, childCount: sourceList.length),
                        );
                      },
                    ),
                  ] else
                    SliverToBoxAdapter(
                      child: ContentState(
                        title: 'This collection has no tracks yet',
                        message: _playlist['source'] == 'user-created'
                            ? 'Find a track, open its options and choose Add to a Playlist.'
                            : 'Refresh this collection or search for more music.',
                        actionLabel: _playlist['source'] == 'user-created'
                            ? 'Find tracks to add'
                            : 'Refresh collection',
                        onAction: _playlist['source'] == 'user-created'
                            ? () => context.go('/search')
                            : _initializePlaylist,
                      ),
                    ),
                  const SliverMiniPlayerBottomSpace(),
                ],
              )
            : ContentState(
                icon: CupertinoIcons.music_albums,
                title: 'Collection unavailable',
                message:
                    'The track list could not be loaded. Check your connection and try again.',
                actionLabel: 'Retry collection',
                onAction: _initializePlaylist,
                secondaryLabel: 'Find other music',
                onSecondary: () => context.go('/search'),
              ),
      ),
    );
  }

  String get _playlistTitle {
    final rawTitle =
        _playlist?['title']?.toString() ??
        widget.playlistData?['title']?.toString() ??
        '';
    if (rawTitle.trim().isEmpty) return 'Collection';
    return widget.isArtist ? normalizeArtistDisplayTitle(rawTitle) : rawTitle;
  }

  Widget _buildPlaylistImage() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    final basePlaylist = _playlist ?? widget.playlistData ?? const {};
    final playlist = widget.isArtist
        ? {
            ...basePlaylist,
            'image': normalizeArtistThumbnailUrl(
              basePlaylist['image']?.toString(),
            ),
          }
        : basePlaylist;
    return GestureDetector(
      onTap: (playlist['list'] as List? ?? []).isEmpty
          ? null
          : () {
              final currentPlaylist = _playlist ?? widget.playlistData;
              final songs = currentPlaylist?['list'] as List? ?? [];
              if (songs.isNotEmpty) {
                HapticFeedback.selectionClick();
                audioHandler.playPlaylistSong(
                  playlist: currentPlaylist,
                  songIndex: 0,
                );
              }
            },
      child: PlaylistCube(
        playlist,
        size: isLandscape ? 250 : screenWidth / commonPlaylistArtworkDivision,
        cubeIcon: widget.cubeIcon,
        showTypeLabel: false,
      ),
    );
  }

  Widget _buildHeaderSection() {
    final playlist = _playlist ?? widget.playlistData ?? const {};
    final songsLength = (playlist['list'] as List? ?? const []).length;
    final isUserCreated = playlist['source'] == 'user-created';
    final hasSecondaryActions =
        (widget.playlistId != null && !isUserCreated && !offlineMode.value) ||
        !offlineMode.value ||
        isUserCreated;

    return Column(
      children: [
        PlaylistHeader(
          _buildPlaylistImage(),
          _playlistTitle,
          songsLength: songsLength,
          isAlbum: playlist['isAlbum'] == true,
          isArtist: widget.isArtist,
        ),
        if (songsLength > 0)
          PlaylistActionButtons(
            onPlay: () =>
                audioHandler.playPlaylistSong(playlist: playlist, songIndex: 0),
            onShuffle: () async {
              final songs = playlist['list'] as List? ?? [];
              if (songs.isEmpty) return;
              await audioHandler.addPlaylistToQueue(
                List<Map>.from(songs.whereType<Map>())..shuffle(),
                replace: true,
                startIndex: 0,
                resetShuffle: false,
              );
            },
          ),
        if (hasSecondaryActions) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 8,
            children: [
              if (widget.playlistId != null &&
                  !isUserCreated &&
                  !offlineMode.value)
                PlaylistLikeButton(
                  playlistId: _resolvedPlaylistId ?? '',
                  playlistData: () => _playlist,
                ),
              if (!offlineMode.value) ...[
                if (songsLength > 0)
                  PlaylistAddToPlaylistButton(
                    resolvePlaylist: () async => _playlist,
                  ),
                if (!isUserCreated) _buildSyncButton(),
              ],
              if (songsLength > 0) _buildDownloadButton(),
              if (isUserCreated) ...[_buildShareButton(), _buildEditButton()],
            ],
          ),
        ],
        if (songsLength > 1) ...[
          const SizedBox(height: 12),
          SortChips<PlaylistSortType>(
            currentSortType: _sortType,
            sortTypes: PlaylistSortType.values,
            sortTypeToString: _getSortTypeDisplayText,
            onSelected: (type) {
              setState(() {
                _sortType = type;
                addOrUpdateData<String>(
                  'settings',
                  'playlistSortType',
                  type.name,
                );
                playlistSortSetting = type.name;
                _sortPlaylist(type);
              });
            },
          ),
        ],
        if (songsLength > 0) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSearchTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              placeholder: 'Search in playlist',
              onChanged: (value) => _searchQueryNotifier.value = value,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildShareButton() {
    final isDark = isAppDarkMode(context);
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: musynSecondarySurface(isDark),
      borderRadius: BorderRadius.circular(22),
      onPressed: () async {
        try {
          final encodedPlaylist = PlaylistSharingService.encodePlaylist(
            _playlist,
          );
          final url = 'musyn://playlist/custom/$encodedPlaylist';
          await Clipboard.setData(ClipboardData(text: url));
          if (mounted) {
            showToast(context, 'Playlist link copied');
          }
        } catch (e, stackTrace) {
          logger.log(
            'Error sharing playlist',
            error: e,
            stackTrace: stackTrace,
          );
          if (mounted) {
            showToast(context, 'Unable to share playlist');
          }
        }
      },
      child: Icon(
        CupertinoIcons.share,
        size: 20,
        color: CupertinoTheme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildSyncButton() {
    final isDark = isAppDarkMode(context);
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: musynSecondarySurface(isDark),
      borderRadius: BorderRadius.circular(22),
      onPressed: _syncing ? null : _handleSyncPlaylist,
      child: _syncing
          ? const CupertinoActivityIndicator()
          : Icon(
              CupertinoIcons.arrow_2_circlepath,
              size: 20,
              color: CupertinoTheme.of(context).primaryColor,
            ),
    );
  }

  Widget _buildEditButton() {
    final isDark = isAppDarkMode(context);
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: musynSecondarySurface(isDark),
      borderRadius: BorderRadius.circular(22),
      onPressed: () async {
        final result = await showCupertinoDialog<Map?>(
          context: context,
          builder: (context) => EditPlaylistDialog(playlistData: _playlist),
        );

        if (result != null) {
          final resolvedPlaylistYtid =
              _playlist['ytid']?.toString() ?? widget.playlistId;
          if (resolvedPlaylistYtid == null ||
              resolvedPlaylistYtid.isEmpty ||
              resolvedPlaylistYtid == 'null') {
            showToast(context, context.l10n.error);
            return;
          }

          final updatedPlaylist = {
            ..._playlist,
            ...result,
            'ytid': resolvedPlaylistYtid,
            'source': _playlist['source'] ?? result['source'],
            'list': result['list'] ?? _playlist['list'],
          };

          // Search root list first, then inside folders.
          final rootIndex = userCustomPlaylists.value.indexWhere(
            (p) => p['ytid'] == resolvedPlaylistYtid,
          );

          if (rootIndex != -1) {
            final updatedPlaylists = List<Map>.from(userCustomPlaylists.value);
            updatedPlaylists[rootIndex] = updatedPlaylist;
            userCustomPlaylists.value = updatedPlaylists;
            unawaited(
              addOrUpdateData<List>(
                'user',
                'customPlaylists',
                userCustomPlaylists.value,
              ),
            );
          } else {
            // Playlist lives inside a folder - update it there.
            final updatedFolders = List<Map>.from(userPlaylistFolders.value);
            for (final folder in updatedFolders) {
              final folderPlaylists = List<Map>.from(
                folder['playlists'] as List? ?? [],
              );
              final fi = folderPlaylists.indexWhere(
                (p) => p['ytid'] == resolvedPlaylistYtid,
              );
              if (fi != -1) {
                folderPlaylists[fi] = updatedPlaylist;
                folder['playlists'] = folderPlaylists;
                break;
              }
            }
            userPlaylistFolders.value = updatedFolders;
            unawaited(
              addOrUpdateData<List>(
                'user',
                'playlistFolders',
                userPlaylistFolders.value,
              ),
            );
          }

          // Update offline playlist if it exists
          unawaited(syncOfflinePlaylistMetadata(updatedPlaylist));

          setState(() {
            _playlist = updatedPlaylist;
            _originalPlaylistList = List<dynamic>.from(
              updatedPlaylist['list'] as List? ?? const [],
            );
            _sortPlaylist(_sortType);
          });
          showToast(context, 'Playlist updated');
        }
      },
      child: Icon(
        CupertinoIcons.pencil,
        size: 20,
        color: CupertinoTheme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildDownloadButton() {
    final playlistId = _playlist?['ytid']?.toString() ?? widget.playlistId;
    if (playlistId == null || playlistId.isEmpty) {
      return const SizedBox.shrink();
    }

    return PlaylistDownloadButton(
      playlistId: playlistId,
      songs: _playlist?['list'] as List? ?? const [],
      resolvePlaylist: () async => _playlist,
    );
  }

  Future<void> _handleSyncPlaylist() async {
    final playlistId = _playlist?['ytid']?.toString();
    if (_syncing || playlistId == null || playlistId.isEmpty) return;
    if (offlineMode.value) {
      showToast(context, 'Go online to refresh this collection.');
      return;
    }
    setState(() {
      _syncing = true;
      _loadFailed = false;
    });
    try {
      Future<Map?> fetch() async {
        if (widget.loadPlaylist != null)
          return widget.loadPlaylist!(playlistId);
        if (widget.isArtist ||
            playlistId.startsWith('MPRE') ||
            playlistId.startsWith('saavn_')) {
          return getPlaylistInfoForWidget(
            playlistId,
            isArtist: widget.isArtist,
            artistName: _playlist?['title']?.toString(),
            artistImage: _playlist?['image']?.toString(),
            preferredVerified: _playlist?['isVerifiedArtist'] == true,
            forceRefresh: true,
          );
        }
        final songs = await getSongsFromPlaylist(
          playlistId,
          forceRefresh: true,
        );
        return {..._playlist as Map, 'list': songs};
      }

      final updated = await fetch().timeout(const Duration(seconds: 20));
      if (!mounted || _resolvedPlaylistId != playlistId) return;
      if (updated == null ||
          updated['list'] is! List ||
          (updated['list'] as List).isEmpty ||
          updated['catalogStatus'] == 'failed')
        throw StateError('No refreshed tracks');
      setState(() {
        _playlist = updated;
        _originalPlaylistList = List<dynamic>.from(updated['list'] as List);
        _sortPlaylist(_sortType);
      });
      showToast(context, context.l10n.playlistUpdated);
    } catch (error, stack) {
      logger.log('Collection refresh failed', error: error, stackTrace: stack);
      if (mounted && _resolvedPlaylistId == playlistId)
        setState(() => _loadFailed = true);
    } finally {
      if (mounted && _resolvedPlaylistId == playlistId)
        setState(() => _syncing = false);
    }
  }

  void _updateSongsListOnRemove(int indexOfRemovedSong, dynamic songToRemove) {
    _originalPlaylistList.removeWhere((s) => s['ytid'] == songToRemove['ytid']);
    final playlistId = _playlist['ytid'];
    if (mounted) {
      setState(() {});
      showToastWithButton(
        context,
        context.l10n.songRemoved,
        context.l10n.undo.toUpperCase(),
        () {
          final result = addSongInCustomPlaylist(
            context,
            playlistId,
            songToRemove,
            indexToInsert: indexOfRemovedSong,
          );
          if (result == context.l10n.songAdded &&
              !_originalPlaylistList.any(
                (song) => song['ytid'] == songToRemove['ytid'],
              )) {
            final safeIndex = indexOfRemovedSong.clamp(
              0,
              _originalPlaylistList.length,
            );
            _originalPlaylistList.insert(safeIndex, songToRemove);
            _sortPlaylist(_sortType);
          }
          if (mounted) setState(() {});
        },
      );
    } else {
      logger.log(
        '(_updateSongsListOnRemove): Widget not mounted, cannot show undo toast.',
      );
    }
  }

  String _getSortTypeDisplayText(PlaylistSortType type) {
    switch (type) {
      case PlaylistSortType.default_:
        return context.l10n.default_;
      case PlaylistSortType.title:
        return context.l10n.name;
      case PlaylistSortType.artist:
        return context.l10n.artist;
      case PlaylistSortType.dateAdded:
        return context.l10n.dateAdded;
    }
  }

  void _sortPlaylist(PlaylistSortType type) {
    if (_playlist == null || _playlist['list'] == null) return;

    switch (type) {
      case PlaylistSortType.default_:
        // Restore original order from backup
        _playlist['list'] = List<dynamic>.from(_originalPlaylistList);
        break;
      case PlaylistSortType.title:
        final playlist = List<dynamic>.from(_playlist['list']);
        sortSongsByKey(playlist, 'title');
        _playlist['list'] = playlist;
        break;
      case PlaylistSortType.artist:
        final playlist = List<dynamic>.from(_playlist['list']);
        sortSongsByKey(playlist, 'artist');
        _playlist['list'] = playlist;
        break;
      case PlaylistSortType.dateAdded:
        _playlist['list'] = List<dynamic>.from(_originalPlaylistList.reversed);
        break;
    }
  }

  Widget _buildSongListItem(
    Map song,
    int index,
    bool isRemovable,
    List sourceList,
  ) {
    final isSearching = _searchQueryNotifier.value.isNotEmpty;
    final fullIndex = isSearching
        ? PlaylistUtils.findSongIndexByYtid(_playlist, song['ytid'])
        : index;

    if (isSearching && fullIndex == -1) {
      logger.log('Warning: Song ${song['ytid']} not found in full playlist');
    }

    return SongTile(
      song: song,
      key: ValueKey('playlist_${song['ytid']}_$index'),
      canRemove: isRemovable && !isSearching,
      onRemove: (isRemovable && !isSearching)
          ? () {
              if (removeSongFromPlaylist(
                _playlist,
                song,
                removeOneAtIndex: index,
              )) {
                _updateSongsListOnRemove(index, song);
              }
            }
          : null,
      onTap: () {
        HapticFeedback.selectionClick();
        audioHandler.playPlaylistSong(
          playlist: _playlist,
          songIndex: fullIndex != -1 ? fullIndex : index,
        );
      },
    );
  }
}
