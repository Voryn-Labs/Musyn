import 'package:audio_service/audio_service.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/utilities/app_utils.dart';
import 'package:musyn/utilities/artwork_provider.dart' show upgradeArtworkUrl;
export 'package:musyn/utilities/artwork_provider.dart' show upgradeArtworkUrl;

Map mediaItemToMap(MediaItem mediaItem) {
  final extras = mediaItem.extras;
  final album = mediaItem.album;
  return {
    'id': mediaItem.id,
    'ytid': extras?['ytid'] ?? mediaItem.id,
    'album': (album == null || album == 'null') ? null : album,
    'artist': mediaItem.artist?.toString(),
    'title': mediaItem.title,
    'artistId': extras?['artistId'],
    'videoAuthor': extras?['videoAuthor'],
    'duration': mediaItem.duration?.inSeconds ??
        extras?['catalogDurationSeconds'] ??
        extras?['duration'],
    'source': extras?['source'] ??
        extras?['catalogOrigin'] ??
        extras?['resolvedSource'] ??
        extras?['downloadSource'],
    'catalogOrigin': extras?['catalogOrigin'],
    'saavnId': extras?['saavnId'],
    'encrypted_media_url': extras?['encrypted_media_url'],
    'media_url': extras?['media_url'],
    'perma_url': extras?['perma_url'],
    'highResImage':
        extras?['highResImage'] ??
        extras?['image'] ??
        mediaItem.artUri?.toString(),
    'image':
        extras?['image'] ??
        extras?['highResImage'] ??
        mediaItem.artUri?.toString(),
    'catalogImage': extras?['catalogImage'],
    'lowResImage': extras?['lowResImage'],
    'isLive': extras?['isLive'] ?? false,
    'isOffline': extras?['isOffline'] ?? false,
    'downloadSource': extras?['downloadSource'],
    'resolvedSource': extras?['resolvedSource'],
    'resolvedBitrate': extras?['resolvedBitrate'],
    'resolvedFormat': extras?['resolvedFormat'],
  };
}

bool _isSquareArtworkCdn(String url) {
  return url.contains('googleusercontent.com') ||
      url.contains('ggpht.com') ||
      url.contains('saavncdn.com');
}

String? _nonEmptyUrl(dynamic value) {
  final url = value?.toString();
  if (url == null || url.isEmpty || url == 'null') return null;
  return url;
}

/// Square-friendly artwork URL for lock-screen / in-app art.
/// Prefers googleusercontent, ggpht, and saavncdn over 16:9 ytimg thumbs.
String? resolveMediaArtworkUrl(Map song, {String? ytid, int targetSize = 400}) {
  final candidates = <String>[
    for (final key in [
      'catalogImage',
      'highResImage',
      'image',
      'lowResImage',
      'thumbnail',
      'artwork',
    ])
      if (_nonEmptyUrl(song[key]) != null) _nonEmptyUrl(song[key])!,
  ];

  var chosen = _nonEmptyUrl(song['catalogImage']);
  for (final url in candidates) {
    if (chosen != null) break;
    if (_isSquareArtworkCdn(url)) {
      chosen = url;
      break;
    }
  }
  chosen ??= candidates.isNotEmpty ? candidates.first : null;

  final validYoutubeId =
      ytid != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(ytid);
  if (chosen != null) {
    return upgradeArtworkUrl(chosen, targetSize: targetSize);
  }
  if (validYoutubeId) {
    return 'https://i.ytimg.com/vi/$ytid/mqdefault.jpg';
  }
  return null;
}


MediaItem mapToMediaItem(Map song) {
  final ytid = song['ytid']?.toString();
  final offlineSong = ytid != null
      ? getOfflineSongByYtid(ytid, verifyFiles: false)
      : <String, dynamic>{};
  // The active playback decision wins over disk presence. Once a track has
  // been resolved to a streaming provider (via source switch), it must not
  // keep presenting as "offline" just because a download exists on disk.
  final resolvedSource = song['resolvedSource']?.toString();
  final bool isOffline;
  if (resolvedSource == 'youtube' || resolvedSource == 'jiosaavn') {
    isOffline = false;
  } else if (resolvedSource == 'offline') {
    isOffline = true;
  } else {
    // Display metadata uses the registry; playback verifies the actual asset.
    isOffline = isSongAlreadyOffline(ytid) || song['isOffline'] == true;
  }
  final downloadSource =
      song['downloadSource'] ?? offlineSong['downloadSource'];

  final artworkUrl = resolveMediaArtworkUrl(song, ytid: ytid);

  final artworkPath =
      _nonEmptyUrl(offlineSong['artworkPath']) ??
      _nonEmptyUrl(song['artworkPath']);
  final hasLocalArt = artworkPath != null;
  final artUri = isOffline && hasLocalArt
      ? (artworkPath.startsWith('file:')
            ? Uri.parse(artworkPath)
            : Uri.file(artworkPath))
      : (artworkUrl != null && artworkUrl.isNotEmpty && artworkUrl != 'null'
            ? Uri.parse(artworkUrl)
            : (ytid != null &&
                      ytid.isNotEmpty &&
                      RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(ytid)
                  ? Uri.parse('https://i.ytimg.com/vi/$ytid/mqdefault.jpg')
                  : null));
  // ytid is the canonical track identity shared by YouTube and JioSaavn.
  // Provider URLs, source labels, and queue-entry ids must never change it.
  final stableId = (ytid == null || ytid.isEmpty)
      ? song['id'].toString()
      : ytid;

  final albumRaw = song['album']?.toString();
  final album = (albumRaw == null || albumRaw.isEmpty || albumRaw == 'null')
      ? null
      : albumRaw;
  final artworkFilePath =
      (isOffline ? offlineSong['artworkPath'] : song['artworkPath'])
          ?.toString() ??
      song['artWorkPath']?.toString() ??
      '';

  return MediaItem(
    id: stableId,
    artist: song['artist']?.toString().trim(),
    album: album,
    title: song['title'].toString(),
    artUri: artUri,
    duration: parseSongDuration(song['duration']),
    extras: {
      'lowResImage': song['lowResImage'],
      'ytid': song['ytid'] ?? song['id'],
      'artistId': song['artistId'],
      'videoAuthor': song['videoAuthor'],
      'isLive': song['isLive'],
      'isOffline': isOffline,
      'source': song['source'] ??
          song['catalogOrigin'] ??
          song['resolvedSource'] ??
          song['downloadSource'],
      'downloadSource': downloadSource,
      'catalogImage': song['catalogImage'],
      'catalogOrigin': song['catalogOrigin'],
      'saavnId': song['saavnId'],
      'encrypted_media_url': song['encrypted_media_url'],
      'media_url': song['media_url'],
      'perma_url': song['perma_url'],
      'highResImage': artworkUrl ?? song['highResImage'] ?? song['image'],
      'artWorkPath': artworkFilePath,
      'artworkPath': artworkFilePath,
      'image': artworkUrl ?? song['image'] ?? song['highResImage'],
      'resolvedSource': song['resolvedSource'],
      'resolvedBitrate': song['resolvedBitrate'],
      'resolvedFormat': song['resolvedFormat'],
      'catalogDurationSeconds': parseSongDuration(song['duration'])?.inSeconds,
      'duration': song['duration'],
    },
  );
}

/// Compares two Duration objects with tolerance for minor differences.
///
/// This prevents unnecessary updates when duration values have minor variations
/// (e.g., due to buffering or precision differences).
bool durationEquals(Duration? prev, Duration? curr) {
  if (prev == curr) return true;
  if (prev == null || curr == null) return prev == curr;

  // Consider durations equal if they differ by less than 1 second
  return (prev - curr).abs() < const Duration(seconds: 1);
}
