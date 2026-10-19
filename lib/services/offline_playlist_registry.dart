import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/library_state.dart';

class OfflinePlaylistRegistry {
  // List of playlists that are fully available offline
  final offlinePlaylists = ValueNotifier<List<dynamic>>(() {
    try {
      if (Hive.isBoxOpen('userNoBackup')) {
        return Hive.box(
          'userNoBackup',
        ).get('offlinePlaylists', defaultValue: []);
      }
    } catch (_) {}
    return [];
  }());

  void reloadOfflinePlaylistsFromStorage() {
    try {
      if (Hive.isBoxOpen('userNoBackup')) {
        offlinePlaylists.value = List.from(
          Hive.box('userNoBackup').get('offlinePlaylists', defaultValue: []),
        );
      }
    } catch (_) {}
  }

  bool isPlaylistDownloaded(String playlistId) {
    return offlinePlaylists.value.any(
      (playlist) => playlist['ytid'] == playlistId,
    );
  }

  Map? getOfflinePlaylist(String playlistId) {
    for (final playlist in offlinePlaylists.value) {
      if (playlist is Map && playlist['ytid']?.toString() == playlistId) {
        return playlist;
      }
    }
    return null;
  }

  /// Marks [playlist] offline when all of its songs are available locally.
  void checkAndAutoMarkOffline(Map playlist) {
    final id = playlist['ytid']?.toString();
    final pList = playlist['list'] as List?;
    if (id == null || pList == null || pList.isEmpty) return;
    if (isPlaylistDownloaded(id)) return;

    final offlineSongIds = userOfflineSongs.value.map((s) => s['ytid']).toSet();
    if (!pList.every((s) => offlineSongIds.contains(s['ytid']))) return;

    offlinePlaylists.value = [
      ...offlinePlaylists.value,
      {
        ...playlist,
        'list': pList,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
      },
    ];
    unawaited(
      addOrUpdateData<List>(
        'userNoBackup',
        'offlinePlaylists',
        offlinePlaylists.value,
      ),
    );
  }
}

final offlinePlaylistRegistry = OfflinePlaylistRegistry();
