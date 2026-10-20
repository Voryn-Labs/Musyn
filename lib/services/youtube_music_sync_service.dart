import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/library_state.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_favorites_store.dart';
import 'package:musyn/services/youtube_public_context.dart';
import 'package:musyn/utilities/youtube_playlist_parser.dart';

class YouTubeMusicSyncService {
  factory YouTubeMusicSyncService() => _instance;

  YouTubeMusicSyncService._internal();
  static final YouTubeMusicSyncService _instance =
      YouTubeMusicSyncService._internal();

  static const _remixContext = {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240101.01.00',
      'hl': 'en',
    },
  };

  final _publicContext = YouTubePublicContext();

  static const _baseUrl = 'https://music.youtube.com/youtubei/v1';

  final ValueNotifier<List<Map<String, dynamic>>> ytMusicPlaylists =
      ValueNotifier([]);
  final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier(null);
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);
  final syncError = ValueNotifier<String?>(null);
  final pendingLikes = ValueNotifier<int>(0);
  final _favorites = YouTubeFavoritesStore();
  Future<bool>? _syncRequest;
  Future<void>? _likeFlush;
  bool _fetchingLikes = false;

  Future<void> initialize() async {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final syncTime = box.get('lastYtSyncTime');
        if (syncTime is int) {
          lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(syncTime);
        }
      }
      await _hydratePlaylistsFromCache();
      if (Hive.isBoxOpen('user')) pendingLikes.value = _favorites.unsentCount;
      if (YouTubeAuthService().isSignedIn.value) unawaited(fullSync());
    } catch (e) {
      logger.log('Error initializing YouTubeMusicSyncService: $e');
    }
  }

  Future<void> _hydratePlaylistsFromCache() async {
    try {
      final cached = await getData('user', 'ytMusicPlaylists');
      if (cached is! List || cached.isEmpty) return;
      final playlists = <Map<String, dynamic>>[];
      for (final item in cached) {
        if (item is Map) {
          playlists.add(Map<String, dynamic>.from(item));
        }
      }
      if (playlists.isNotEmpty && ytMusicPlaylists.value.isEmpty) {
        _applyLikedMusicCount(playlists);
        ytMusicPlaylists.value = playlists;
      }
    } catch (e) {
      logger.log('Error hydrating YT playlists cache: $e');
    }
  }

  Future<void> _persistPlaylists(List<Map<String, dynamic>> playlists) async {
    try {
      await addOrUpdateData<List>('user', 'ytMusicPlaylists', playlists);
    } catch (e) {
      logger.log('Error persisting YT playlists: $e');
    }
  }

  bool _isValidYouTubeVideoId(String id) {
    return id.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id);
  }

  Future<Map<String, dynamic>> _authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final authService = YouTubeAuthService();
    final headers = authService.getAuthHeaders();
    if (headers.isEmpty) {
      throw Exception('Not authenticated');
    }
    final version = await _publicContext.version();
    return _post(
      endpoint,
      {
        ...body,
        'context': {
          'client': {..._remixContext['client']!, 'clientVersion': version},
        },
      },
      {
        ...headers,
        'User-Agent': YouTubePublicContext.userAgent,
        'Referer': 'https://music.youtube.com/',
        'X-Youtube-Client-Name': '67',
        'X-Youtube-Client-Version': version,
        'X-Origin': 'https://music.youtube.com',
      },
    );
  }

  /// Charts / explore work without a signed-in session.
  Future<Map<String, dynamic>> _publicPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final version = await _publicContext.version();
    final context = Map<String, dynamic>.from(
      body['context'] as Map? ?? _remixContext,
    );
    final client = Map<String, dynamic>.from(context['client'] as Map? ?? {});
    context['client'] = {
      ...client,
      'clientName': 'WEB_REMIX',
      'clientVersion': version,
    };
    return _post(
      endpoint,
      {...body, 'context': context},
      {
        'User-Agent': YouTubePublicContext.userAgent,
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
        'X-Youtube-Client-Name': '67',
        'X-Youtube-Client-Version': version,
      },
    );
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
    Map<String, String> extraHeaders,
  ) async {
    final headers = Map<String, String>.from(extraHeaders)
      ..['Content-Type'] = 'application/json';

    final fullBody = {'context': _remixContext, ...body};

    final response = await http
        .post(
          Uri.parse('$_baseUrl/${endpoint.replaceFirst(RegExp('^/+'), '')}'),
          headers: headers,
          body: jsonEncode(fullBody),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('YouTube API error: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is Map && data['error'] != null)
      throw StateError('YouTube rejected the request');
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  String? _runsText(Map<String, dynamic>? node) {
    final runs = node?['runs'];
    if (runs is! List) return null;
    return runs.map((run) => (run as Map)['text']?.toString() ?? '').join();
  }

  int? _parseTrackDurationSeconds(Map<String, dynamic> item) {
    final fixedColumns = item['fixedColumns'];
    if (fixedColumns is List) {
      for (final col in fixedColumns) {
        if (col is! Map) continue;
        final renderer =
            col['musicResponsiveListItemFixedColumnRenderer'] as Map?;
        final text = _runsText(renderer?['text'] as Map<String, dynamic>?);
        final seconds = _clockTextToSeconds(text);
        if (seconds != null) return seconds;
      }
    }
    final lengthText = item['lengthText'];
    if (lengthText is Map) {
      return _clockTextToSeconds(
        _runsText(Map<String, dynamic>.from(lengthText)),
      );
    }
    if (lengthText is String) return _clockTextToSeconds(lengthText);
    return null;
  }

  int? _clockTextToSeconds(String? text) {
    if (text == null || text.isEmpty) return null;
    final parts = text.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final nums = parts.map(int.tryParse).toList();
    if (nums.any((n) => n == null)) return null;
    final ints = nums.cast<int>();
    if (ints.length == 2) return ints[0] * 60 + ints[1];
    return ints[0] * 3600 + ints[1] * 60 + ints[2];
  }

  Iterable<Map<String, dynamic>> _findRenderers(
    dynamic node,
    String key,
  ) sync* {
    if (node is Map) {
      final match = node[key];
      if (match is Map) yield Map<String, dynamic>.from(match);
      for (final value in node.values) {
        yield* _findRenderers(value, key);
      }
    } else if (node is List) {
      for (final value in node) {
        yield* _findRenderers(value, key);
      }
    }
  }

  String? _extractVideoId(Map<String, dynamic> renderer) {
    try {
      final overlay = renderer['overlay'] as Map?;
      final overlayRenderer =
          overlay?['musicItemThumbnailOverlayRenderer'] as Map?;
      final content = overlayRenderer?['content'] as Map?;
      final playBtn = content?['musicPlayButtonRenderer'] as Map?;
      final nav = playBtn?['playNavigationEndpoint'] as Map?;
      final watch = nav?['watchEndpoint'] as Map?;
      final fromOverlay = watch?['videoId']?.toString();
      if (fromOverlay != null && fromOverlay.isNotEmpty) return fromOverlay;
    } catch (_) {
      // Fall through to other videoId locations used by charts/explore.
    }
    final playlistItemData = renderer['playlistItemData'] as Map?;
    final fromPlaylist = playlistItemData?['videoId']?.toString();
    if (fromPlaylist != null && fromPlaylist.isNotEmpty) return fromPlaylist;
    final nav = renderer['navigationEndpoint'] as Map?;
    final watch = nav?['watchEndpoint'] as Map?;
    return watch?['videoId']?.toString();
  }

  List<Map<String, dynamic>> _parseTrackRenderers(
    Map<String, dynamic> response,
  ) {
    final tracks = <Map<String, dynamic>>[];
    for (final item in _findRenderers(
      response,
      'musicResponsiveListItemRenderer',
    )) {
      final videoId = _extractVideoId(item);
      if (videoId == null) continue;

      final flexColumns = item['flexColumns'];
      if (flexColumns is! List) continue;

      var title = '';
      var artist = '';

      if (flexColumns.isNotEmpty) {
        final col0 = flexColumns[0] as Map?;
        final col0Renderer =
            col0?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
        title = _runsText(col0Renderer?['text'] as Map<String, dynamic>?) ?? '';
      }

      if (flexColumns.length > 1) {
        final col1 = flexColumns[1] as Map?;
        final col1Renderer =
            col1?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
        artist =
            _runsText(col1Renderer?['text'] as Map<String, dynamic>?) ?? '';
      }

      String? imageUrl;
      final thumbnailMap = item['thumbnail'] as Map?;
      final musicThumbnailRenderer =
          thumbnailMap?['musicThumbnailRenderer'] as Map?;
      final thumbnailData = musicThumbnailRenderer?['thumbnail'] as Map?;
      final thumbnails = thumbnailData?['thumbnails'];
      if (thumbnails is List && thumbnails.isNotEmpty) {
        final lastThumb = thumbnails.last as Map?;
        imageUrl = lastThumb?['url']?.toString();
      }

      final durationSeconds = _parseTrackDurationSeconds(item);

      tracks.add({
        'ytid': videoId,
        'title': title,
        'artist': artist,
        'image': imageUrl ?? '',
        'source': 'youtube',
        'catalogOrigin': 'youtube',
        if (durationSeconds != null) 'duration': durationSeconds,
      });
    }
    return tracks;
  }

  Future<List<Map<String, dynamic>>> fetchTrendingTracks() async {
    final country = chartCountry.value;
    try {
      final charts = await fetchChartPlaylists(country: country);
      if (country != chartCountry.value) return [];
      final chartId = YouTubePlaylistParser.topSongsId(charts);
      if (chartId == null) {
        trendingSongs.value = [];
        // A region may expose only music-video charts. That is availability,
        // not a failed network request; never substitute random videos.
        trendingError.value = null;
        return [];
      }
      final tracks = await fetchPlaylistTracks(
        chartId,
        publicOnly: true,
        limit: 20,
      );
      if (country != chartCountry.value) return [];
      final ranked = tracks.take(20).toList();
      for (var i = 0; i < ranked.length; i++) {
        ranked[i] = {...ranked[i], 'chartId': chartId, 'chartRank': i + 1};
      }
      trendingSongs.value = ranked;
      trendingError.value = ranked.isEmpty
          ? 'Unable to load this chart.'
          : null;
      return ranked;
    } catch (e) {
      logger.log('Error fetching chart tracks: $e');
      if (country == chartCountry.value)
        trendingError.value = 'Unable to refresh song charts.';
      return [];
    }
  }

  final _chartRequests = <String, Future<List<Map<String, dynamic>>>>{};

  Future<List<Map<String, dynamic>>> fetchChartPlaylists({String? country}) {
    final selected = country ?? chartCountry.value;
    final region = chartCountries.containsKey(selected) ? selected : 'IN';
    return _chartRequests.putIfAbsent(
      region,
      () => _fetchChartPlaylists(region).whenComplete(() {
        _chartRequests.remove(region);
      }),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchChartPlaylists(
    String country,
  ) async {
    try {
      final response = await _publicPost('/browse', {
        'context': {
          'client': {
            ..._remixContext['client']!,
            'gl': country == 'ZZ' ? 'US' : country,
          },
        },
        'browseId': 'FEmusic_charts',
        'formData': {
          'selectedValues': [country],
        },
      });
      final charts = YouTubePlaylistParser.officialCharts(
        response,
        country: country,
      );
      if (charts.isEmpty) throw StateError('No official charts returned');
      if (Hive.isBoxOpen('cache'))
        await addOrUpdateData<List>('cache', 'officialCharts_$country', charts);
      return charts;
    } catch (error) {
      if (Hive.isBoxOpen('cache')) {
        final cached = await getData(
          'cache',
          'officialCharts_$country',
          cachingDuration: const Duration(days: 3),
        );
        if (cached is List && cached.isNotEmpty)
          return cached
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
      }
      rethrow;
    }
  }

  /// Server-defined Explore destinations: no search phrases masquerading as charts.
  Future<List<Map<String, dynamic>>> fetchMoodCategories() async {
    final response = await _browsePost({
      'browseId': 'FEmusic_moods_and_genres',
    });
    return YouTubePlaylistParser.moodCategories(response);
  }

  Future<List<Map<String, dynamic>>> fetchExploreCollections(
    String browseId, {
    String? params,
  }) async {
    final response = await _browsePost({
      'browseId': browseId,
      if (params != null) 'params': params,
    });
    return YouTubePlaylistParser.charts(response);
  }

  Future<Map<String, dynamic>> _browsePost(Map<String, dynamic> body) async {
    if (YouTubeAuthService().isSignedIn.value) {
      try {
        return await _authenticatedPost('/browse', body);
      } catch (_) {}
    }
    return _publicPost('/browse', body);
  }

  Future<List<Map<String, dynamic>>> fetchLikedSongs() async {
    // FEmusic_liked_videos is the library-songs feed, not Liked Music.
    // Personal collections must never fall back to anonymous browse requests.
    return _browseAllTracks('VLLM', authenticatedOnly: true);
  }

  Future<List<Map<String, dynamic>>> fetchUserPlaylists() async {
    try {
      final response = await _authenticatedPost('/browse', {
        'browseId': 'FEmusic_liked_playlists',
      });

      final playlists = <Map<String, dynamic>>[];
      for (final item in _findRenderers(response, 'musicTwoRowItemRenderer')) {
        final nav = item['navigationEndpoint'] as Map?;
        final browse = nav?['browseEndpoint'] as Map?;
        final playlistId = browse?['browseId']?.toString();

        if (playlistId == null) continue;

        final title = _runsText(item['title'] as Map<String, dynamic>?) ?? '';

        String? imageUrl;
        final thumbnailRenderer = item['thumbnailRenderer'] as Map?;
        final musicThumbnailRenderer =
            thumbnailRenderer?['musicThumbnailRenderer'] as Map?;
        final thumbnail = musicThumbnailRenderer?['thumbnail'] as Map?;
        final thumbnails = thumbnail?['thumbnails'];
        if (thumbnails is List && thumbnails.isNotEmpty) {
          final lastThumb = thumbnails.last as Map?;
          imageUrl = lastThumb?['url']?.toString();
        }

        final subtitle =
            _runsText(item['subtitle'] as Map<String, dynamic>?) ?? '';
        final count = _parseTrackCount(subtitle);

        playlists.add({
          'playlistId': playlistId,
          'title': title,
          'image': imageUrl ?? '',
          // Library UI reads `count`; keep subtitle as `trackCount` for display fallback.
          'count': count ?? 0,
          'trackCount': subtitle,
        });
      }
      _applyLikedMusicCount(playlists);
      return playlists;
    } catch (e) {
      logger.log('Error fetching user playlists: $e');
      rethrow;
    }
  }

  /// Extracts a song count from YT Music subtitle runs (e.g. "Playlist • 42 songs").
  int? _parseTrackCount(String subtitle) {
    if (subtitle.isEmpty) return null;
    final withUnit = RegExp(
      r'(\d[\d,]*)\s*(songs?|tracks?)',
      caseSensitive: false,
    ).firstMatch(subtitle);
    final raw =
        withUnit?.group(1) ??
        RegExp(r'(\d[\d,]*)').firstMatch(subtitle)?.group(1);
    if (raw == null) return null;
    return int.tryParse(raw.replaceAll(',', ''));
  }

  Future<List<Map<String, dynamic>>> fetchPlaylistTracks(
    String playlistId, {
    bool publicOnly = false,
    int? limit,
  }) async {
    try {
      if (isLikedMusicPlaylist({'playlistId': playlistId})) {
        return await fetchLikedSongs();
      }
      final browseId =
          playlistId.startsWith('VL') || playlistId.startsWith('FE')
          ? playlistId
          : 'VL$playlistId';
      return await _browseAllTracks(
        browseId,
        publicOnly: publicOnly,
        limit: limit,
      );
    } catch (e) {
      logger.log('Error fetching playlist tracks: $e');
      return [];
    }
  }

  /// Walks browse + continuation pages until exhausted (capped for safety).
  Future<List<Map<String, dynamic>>> _browseAllTracks(
    String browseId, {
    bool publicOnly = false,
    bool authenticatedOnly = false,
    int? limit,
  }) async {
    final tracks = <Map<String, dynamic>>[];
    final seen = <String>{};

    Future<Map<String, dynamic>> browse(Map<String, dynamic> body) =>
        authenticatedOnly
        ? _authenticatedPost('/browse', body)
        : publicOnly
        ? _publicPost('/browse', body)
        : _browsePost(body);
    var response = await browse({'browseId': browseId});
    if (authenticatedOnly &&
        (YouTubePlaylistParser.playlistScope(response)['playlistSections']
                as List)
            .isEmpty) {
      throw StateError(
        'YouTube did not return the signed-in Liked Music collection',
      );
    }
    _appendUniqueTracks(
      tracks,
      seen,
      _parseTrackRenderers(YouTubePlaylistParser.playlistScope(response)),
    );

    var continuation = _extractContinuation(
      YouTubePlaylistParser.playlistScope(response),
    );
    var pages = 0;
    const maxPages = 25;

    while (continuation != null &&
        continuation.isNotEmpty &&
        pages < maxPages &&
        (limit == null || tracks.length < limit)) {
      pages++;
      response = await browse({'continuation': continuation});
      final pageTracks = _parseTrackRenderers(
        YouTubePlaylistParser.playlistScope(response),
      );
      if (pageTracks.isEmpty) break;
      final before = tracks.length;
      _appendUniqueTracks(tracks, seen, pageTracks);
      if (tracks.length == before) break;
      continuation = _extractContinuation(
        YouTubePlaylistParser.playlistScope(response),
      );
    }

    return limit == null ? tracks : tracks.take(limit).toList();
  }

  void _appendUniqueTracks(
    List<Map<String, dynamic>> dest,
    Set<String> seen,
    List<Map<String, dynamic>> page,
  ) {
    for (final track in page) {
      final id = track['ytid']?.toString();
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      dest.add(track);
    }
  }

  String? _extractContinuation(Map<String, dynamic> response) {
    for (final node in _findRenderers(response, 'nextContinuationData')) {
      final token = node['continuation']?.toString();
      if (token != null && token.isNotEmpty) return token;
    }
    for (final node in _findRenderers(response, 'continuationEndpoint')) {
      final cont = node['continuationCommand'] as Map?;
      final token = cont?['token']?.toString();
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchPersonalizedMixes() async {
    try {
      final response = await _authenticatedPost('/browse', {
        'browseId': 'FEmusic_home',
      });

      final mixes = <Map<String, dynamic>>[];
      for (final item in _findRenderers(response, 'musicTwoRowItemRenderer')) {
        final title = _runsText(item['title'] as Map<String, dynamic>?) ?? '';
        if (title.toLowerCase().contains('mix')) {
          final nav = item['navigationEndpoint'] as Map?;
          final browse = nav?['browseEndpoint'] as Map?;
          final playlistId = browse?['browseId']?.toString();

          if (playlistId == null) continue;

          String? imageUrl;
          final thumbnailRenderer = item['thumbnailRenderer'] as Map?;
          final musicThumbnailRenderer =
              thumbnailRenderer?['musicThumbnailRenderer'] as Map?;
          final thumbnail = musicThumbnailRenderer?['thumbnail'] as Map?;
          final thumbnails = thumbnail?['thumbnails'];
          if (thumbnails is List && thumbnails.isNotEmpty) {
            final lastThumb = thumbnails.last as Map?;
            imageUrl = lastThumb?['url']?.toString();
          }

          mixes.add({
            'playlistId': playlistId,
            'title': title,
            'image': imageUrl ?? '',
          });
        }
      }
      return mixes;
    } catch (e) {
      logger.log('Error fetching personalized mixes: $e');
      return [];
    }
  }

  Future<bool> likeSong(String videoId) async {
    if (!_isValidYouTubeVideoId(videoId)) {
      return false; // JioSaavn or non-YouTube ID, ignore safely
    }
    try {
      await _authenticatedPost('/like/like', {
        'target': {'videoId': videoId},
      });
      return true;
    } catch (e) {
      logger.log('Error liking song: $e');
      return false;
    }
  }

  Future<bool> unlikeSong(String videoId) async {
    if (!_isValidYouTubeVideoId(videoId)) {
      return false;
    }
    try {
      await _authenticatedPost('/like/removelike', {
        'target': {'videoId': videoId},
      });
      return true;
    } catch (e) {
      logger.log('Error unliking song: $e');
      return false;
    }
  }

  String _normalizePlaylistIdForMutation(String playlistId) {
    var id = playlistId.trim();
    if (id.startsWith('VL')) {
      id = id.substring(2);
    }
    return id;
  }

  Future<bool> addVideoToPlaylist(String playlistId, String videoId) async {
    return await addVideosToPlaylist(playlistId, [videoId]) == 1;
  }

  Future<int> addVideosToPlaylist(
    String playlistId,
    List<String> videoIds,
  ) async {
    if (videoIds.isEmpty || videoIds.any((id) => !_isValidYouTubeVideoId(id)))
      return 0;
    final cleanId = _normalizePlaylistIdForMutation(playlistId);
    if (cleanId.isEmpty) return 0;
    var added = 0;
    try {
      final unique = videoIds.toSet().toList();
      for (var start = 0; start < unique.length; start += 50) {
        final end = (start + 50).clamp(0, unique.length);
        await _authenticatedPost('/browse/edit_playlist', {
          'playlistId': cleanId,
          'actions': [
            for (final videoId in unique.sublist(start, end))
              {'action': 'ACTION_ADD_VIDEO', 'addedVideoId': videoId},
          ],
        });
        added += end - start;
      }
      return added;
    } catch (e) {
      logger.log('Error adding video to YT Music playlist: $e');
      return added;
    }
  }

  Future<String?> createUserPlaylist(String title, {String? videoId}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    try {
      final body = <String, dynamic>{
        'title': trimmed,
        if (videoId != null && _isValidYouTubeVideoId(videoId))
          'videoIds': [videoId],
      };
      final response = await _authenticatedPost('/playlist/create', body);
      final id = response['playlistId']?.toString();
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (e) {
      logger.log('Error creating YT Music playlist: $e');
      return null;
    }
  }

  /// Content Playback Nonce used by YouTube stats endpoints.
  String _generateCpn() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String? _extractPlaybackTrackingUrl(Map<String, dynamic> player) {
    final tracking = player['playbackTracking'];
    if (tracking is! Map) return null;
    final urlNode = tracking['videostatsPlaybackUrl'];
    if (urlNode is Map) return urlNode['baseUrl']?.toString();
    if (urlNode is String) return urlNode;
    return null;
  }

  Future<void> _pingNextForHistory(String videoId) async {
    await _authenticatedPost('/next', {
      'videoId': videoId,
      'isAudioOnly': true,
    });
  }

  /// Fetches a batch of next tracks from the YouTube Music Radio stream (`RDAMVM` + `/next`).
  Future<List<Map<String, dynamic>>> fetchRadioTracks(
    String videoId, {
    int limit = 5,
  }) async {
    if (!_isValidYouTubeVideoId(videoId)) return [];
    try {
      Map<String, dynamic> response;
      try {
        response = await _authenticatedPost('/next', {
          'videoId': videoId,
          'playlistId': 'RDAMVM$videoId',
          'isAudioOnly': true,
        });
      } catch (_) {
        response = await _publicPost('/next', {
          'videoId': videoId,
          'playlistId': 'RDAMVM$videoId',
          'isAudioOnly': true,
        });
      }

      final results = <Map<String, dynamic>>[];
      for (final item in _findRenderers(
        response,
        'playlistPanelVideoRenderer',
      )) {
        if (results.length >= limit) break;
        final id = item['videoId']?.toString();
        if (id == null || id.isEmpty || id == videoId) continue;
        if (!_isValidYouTubeVideoId(id)) continue;

        final title =
            _runsText(item['title'] as Map<String, dynamic>?)?.trim() ?? '';
        final artist =
            _runsText(
              item['longBylineText'] as Map<String, dynamic>?,
            )?.trim() ??
            _runsText(
              item['shortBylineText'] as Map<String, dynamic>?,
            )?.trim() ??
            '';
        if (title.isEmpty || artist.isEmpty) continue;

        String? imageUrl;
        final thumbnails = item['thumbnail'] is Map
            ? (item['thumbnail'] as Map)['thumbnails']
            : null;
        if (thumbnails is List && thumbnails.isNotEmpty) {
          final last = thumbnails.last;
          if (last is Map) imageUrl = last['url']?.toString();
        }

        final lengthText = item['lengthText'];
        int? durationSeconds;
        if (lengthText is Map) {
          durationSeconds = _clockTextToSeconds(
            _runsText(Map<String, dynamic>.from(lengthText)),
          );
        }

        results.add({
          'ytid': id,
          'title': title,
          'artist': artist,
          'image': imageUrl ?? '',
          'highResImage': imageUrl ?? '',
          'source': 'youtube',
          'catalogOrigin': 'youtube',
          if (durationSeconds != null) 'duration': durationSeconds,
        });
      }
      return results;
    } catch (e) {
      logger.log('fetchRadioTracks failed for $videoId: $e');
      return [];
    }
  }

  /// Next song from YouTube Music radio (`RDAMVM` + `/next`), preferred over
  /// watch-page HTML related-video parsing.
  Future<Map<String, dynamic>?> fetchRadioNextTrack(String videoId) async {
    final tracks = await fetchRadioTracks(videoId, limit: 1);
    return tracks.firstOrNull;
  }

  /// Reports a play to YouTube Music watch history when the user is signed in.
  /// Uses player playback-tracking URLs (same path as official clients); falls
  /// back to an authenticated `/next` nudge if tracking URLs are missing.
  Future<bool> reportSongPlayed(String videoId) async {
    if (!_isValidYouTubeVideoId(videoId)) {
      return false;
    }
    try {
      final player = await _authenticatedPost('/player', {
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      });

      final playbackUrl = _extractPlaybackTrackingUrl(player);
      if (playbackUrl == null || playbackUrl.isEmpty) {
        await _pingNextForHistory(videoId);
        return true;
      }

      final cpn = _generateCpn();
      final normalized = playbackUrl.replaceFirst('https://s.', 'https://www.');
      final uri = Uri.parse(normalized);
      final params = Map<String, String>.from(uri.queryParameters)
        ..['cpn'] = cpn
        ..['fmt'] = '251'
        ..['rtn'] = '0'
        ..['rt'] = '0';

      final headers = YouTubeAuthService().getAuthHeaders();
      if (headers.isEmpty) return false;
      headers['User-Agent'] =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148';

      final response = await http.get(
        uri.replace(queryParameters: params),
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return true;
      }

      await _pingNextForHistory(videoId);
      return true;
    } catch (e) {
      logger.log('Error reporting song played: $e');
      try {
        await _pingNextForHistory(videoId);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> recordFavorite(String id, bool liked, Map? song) async {
    if (!Hive.isBoxOpen('user') || !YouTubeFavoritesStore.validId(id)) return;
    await _favorites.record(id, liked, song);
    pendingLikes.value = _favorites.unsentCount;
    if (!_fetchingLikes &&
        YouTubeAuthService().isSignedIn.value &&
        ytAutoSyncLikes.value) {
      unawaited(flushPendingLikes());
    }
  }

  Future<void> flushPendingLikes() {
    if (_likeFlush != null) return _likeFlush!;
    return _likeFlush = _flushPendingLikes().whenComplete(() {
      _likeFlush = null;
    });
  }

  Future<void> _flushPendingLikes() async {
    if (!Hive.isBoxOpen('user') ||
        !YouTubeAuthService().isSignedIn.value ||
        !ytAutoSyncLikes.value)
      return;
    // Serialize mutations so rapid like/unlike taps cannot reach YouTube backwards.
    final attempted = <String>{};
    while (YouTubeAuthService().isSignedIn.value && ytAutoSyncLikes.value) {
      final edits = _favorites.pending;
      final remaining = edits.entries.where(
        (e) =>
            e.value['sent'] != true &&
            !attempted.contains('${e.key}:${e.value['revision']}'),
      );
      if (remaining.isEmpty) break;
      final edit = remaining.first;
      attempted.add('${edit.key}:${edit.value['revision']}');
      final ok = edit.value['liked'] == true
          ? await likeSong(edit.key)
          : await unlikeSong(edit.key);
      if (!ok) {
        syncError.value =
            'Some favorites are saved on this iPhone and waiting to sync. Retry when connected.';
        break;
      }
      await _favorites.acknowledge(edit.key, edit.value['revision']);
    }
    pendingLikes.value = _favorites.unsentCount;
  }

  Future<bool> syncLikedSongs() async {
    if (!ytAutoSyncLikes.value) return true;
    _fetchingLikes = true;
    try {
      await _favorites.seedLocalLikes(userLikedSongsList.value);
      final ytLikes = await fetchLikedSongs();
      await _favorites.confirmSnapshot(ytLikes);
      final merged = _favorites.merge(ytLikes, userLikedSongsList.value);
      userLikedSongsList.value = merged;
      await addOrUpdateData<List>('user', 'likedSongs', merged);
      await _favorites.rememberRemote(ytLikes);
      _patchLikedMusicPlaylistCount(ytLikes.length);
      await flushPendingLikes();
      return _favorites.unsentCount == 0;
    } catch (e) {
      // Preserve the last library and every pending local edit on any failure.
      logger.log('Error syncing liked songs: $e');
      syncError.value =
          'YouTube favorites could not sync. Your saved favorites are safe on this iPhone.';
      return false;
    } finally {
      _fetchingLikes = false;
      if (Hive.isBoxOpen('user')) pendingLikes.value = _favorites.unsentCount;
    }
  }

  Future<bool> syncPlaylists() async {
    if (!ytAutoSyncPlaylists.value) return true;
    try {
      final playlists = await fetchUserPlaylists();
      ytMusicPlaylists.value = playlists;
      await _persistPlaylists(playlists);
      return true;
    } catch (e) {
      logger.log('Error syncing playlists: $e');
      syncError.value =
          'YouTube playlists could not sync. Try reconnecting your account.';
      return false;
    }
  }

  Future<bool> fullSync() {
    if (_syncRequest != null) return _syncRequest!;
    return _syncRequest = _fullSync().whenComplete(() {
      _syncRequest = null;
    });
  }

  Future<bool> _fullSync() async {
    if (!YouTubeAuthService().isSignedIn.value) return false;
    isSyncing.value = true;
    syncError.value = null;
    try {
      final results = await Future.wait([syncLikedSongs(), syncPlaylists()]);
      final ok = results.every((result) => result);
      if (ok) _updateSyncTime();
      return ok;
    } catch (e) {
      logger.log('Error during full sync: $e');
      syncError.value = 'YouTube library could not sync. Please retry.';
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  void _updateSyncTime() {
    final now = DateTime.now();
    lastSyncTime.value = now;
    if (Hive.isBoxOpen('settings')) {
      unawaited(
        addOrUpdateData<int>(
          'settings',
          'lastYtSyncTime',
          now.millisecondsSinceEpoch,
        ),
      );
    }
  }

  void _applyLikedMusicCount(List<Map<String, dynamic>> playlists) {
    final likes = userLikedSongsList.value.length;
    if (likes <= 0) return;
    for (final playlist in playlists) {
      if (isLikedMusicPlaylist(playlist)) {
        playlist['count'] = likes;
      }
    }
  }

  void _patchLikedMusicPlaylistCount(int count) {
    final playlists = [
      for (final playlist in ytMusicPlaylists.value)
        Map<String, dynamic>.from(playlist),
    ];
    var changed = false;
    for (final playlist in playlists) {
      if (isLikedMusicPlaylist(playlist) && playlist['count'] != count) {
        playlist['count'] = count;
        changed = true;
      }
    }
    if (!changed) return;
    ytMusicPlaylists.value = playlists;
    unawaited(_persistPlaylists(playlists));
  }
}

/// YouTube Music's auto "Liked music" playlist has no song count in its
/// subtitle ("Auto playlist"), so library cards would otherwise show 0.
bool isLikedMusicPlaylist(Map playlist) {
  final id = '${playlist['playlistId'] ?? playlist['ytid'] ?? ''}'
      .toLowerCase()
      .trim();
  final title = '${playlist['title'] ?? ''}'.toLowerCase().trim();
  if (id == 'lm' ||
      id == 'vllm' ||
      id.contains('liked_videos') ||
      id.contains('music_liked')) {
    return true;
  }
  return title == 'liked music' ||
      title == 'liked songs' ||
      title == 'liked videos';
}
