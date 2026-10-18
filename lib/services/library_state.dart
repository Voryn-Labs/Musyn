import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:musified/database/albums.db.dart';
import 'package:musified/database/playlists.db.dart';

List<Map> playlists = [...playlistsDB, ...albumsDB];

T _safeUserListGet<T>(String key, T defaultValue) {
  try {
    if (!Hive.isBoxOpen('user')) return defaultValue;
    final v = Hive.box('user').get(key, defaultValue: defaultValue);
    if (v is T) return v;
    return defaultValue;
  } catch (_) {
    return defaultValue;
  }
}

final userPlaylists = ValueNotifier<List<String>>(
  List<String>.from(_safeUserListGet<List>('playlists', [])),
);
final userCustomPlaylists = ValueNotifier<List<Map>>(
  List<Map>.from(_safeUserListGet<List>('customPlaylists', [])),
);
final userLikedPlaylists = ValueNotifier<List<Map>>(
  List<Map>.from(_safeUserListGet<List>('likedPlaylists', [])),
);
final userPlaylistFolders = ValueNotifier<List<Map>>(
  List<Map>.from(_safeUserListGet<List>('playlistFolders', [])),
);
final pinnedPlaylistIds = ValueNotifier<List<String>>(
  List<String>.from(_safeUserListGet<List>('pinnedPlaylistIds', [])),
);
final onlinePlaylists = ValueNotifier<List<Map>>([]);
T _safeUserNoBackupGet<T>(String key, T defaultValue) {
  try {
    if (!Hive.isBoxOpen('userNoBackup')) return defaultValue;
    final v = Hive.box('userNoBackup').get(key, defaultValue: defaultValue);
    if (v is T) return v;
    return defaultValue;
  } catch (_) {
    return defaultValue;
  }
}

ValueNotifier<List> userLikedSongsList = ValueNotifier<List>(
  _safeUserListGet<List>('likedSongs', []),
);

ValueNotifier<List> userRecentlyPlayed = ValueNotifier<List>(
  _safeUserListGet<List>('recentlyPlayedSongs', []),
);

final trendingSongs = ValueNotifier<List>([]);
final trendingError = ValueNotifier<String?>(null);

ValueNotifier<List> userOfflineSongs = ValueNotifier<List>(
  _safeUserNoBackupGet<List>('offlineSongs', []),
);

List<Map> getUserCustomPlaylists() {
  return [
    ...userCustomPlaylists.value
        .where((p) => p['source'] == 'user-created')
        .cast<Map>(),
    for (final folder in userPlaylistFolders.value)
      ...(folder['playlists'] as List<dynamic>? ?? [])
          .where((p) => p['source'] == 'user-created')
          .cast<Map>(),
  ];
}
