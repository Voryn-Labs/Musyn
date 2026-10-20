import 'package:hive/hive.dart';

/// Durable local intent. A failed request or a remote refresh must never undo
/// a user's heart tap. Entries stay until that exact revision is acknowledged.
class YouTubeFavoritesStore {
  static int _revision = DateTime.now().microsecondsSinceEpoch;
  static bool validId(String id) => RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id);
  Box get _box => Hive.box('user');
  Map<String, Map> get pending => {
    for (final entry
        in (_box.get('youtubeLikeEdits', defaultValue: {}) as Map).entries)
      if (entry.value is Map) entry.key.toString(): Map.from(entry.value),
  };
  Set<String> get known =>
      Set<String>.from(_box.get('youtubeKnownLikes', defaultValue: <String>[]));
  Future<void> record(String id, bool liked, Map? song) async {
    if (!validId(id)) return;
    await _box.put('youtubeLikeEdits', {
      ...pending,
      id: {
        'liked': liked,
        'revision': ++_revision,
        if (song != null) 'song': Map.from(song),
      },
    });
  }

  Future<void> acknowledge(String id, dynamic revision) async {
    final edits = pending;
    if (edits[id]?['revision'] != revision) return;
    edits.update(id, (value) => {...value, 'sent': true});
    await _box.put('youtubeLikeEdits', edits);
  }

  Future<void> seedLocalLikes(List local) async {
    final edits = pending;
    final remote = known;
    for (final song in local.whereType<Map>()) {
      final id = song['ytid']?.toString() ?? '';
      if (validId(id) && !remote.contains(id) && !edits.containsKey(id)) {
        edits[id] = {
          'liked': true,
          'revision': ++_revision,
          'song': Map.from(song),
        };
      }
    }
    await _box.put('youtubeLikeEdits', edits);
  }

  Future<void> confirmSnapshot(List<Map<String, dynamic>> remote) async {
    final ids = remote.map((song) => '${song['ytid']}').toSet();
    final edits = pending
      ..removeWhere(
        (id, edit) =>
            edit['sent'] == true && ids.contains(id) == (edit['liked'] == true),
      );
    await _box.put('youtubeLikeEdits', edits);
  }

  int get unsentCount =>
      pending.values.where((edit) => edit['sent'] != true).length;
  List<Map> merge(List<Map<String, dynamic>> remote, List local) {
    final edits = pending;
    final result = <String, Map>{};
    for (final song in local.whereType<Map>()) {
      final id = song['ytid']?.toString() ?? '';
      // Non-YouTube favorites remain local and are never uploaded as video IDs.
      if (id.isNotEmpty && !validId(id)) result[id] = Map.from(song);
    }
    for (final song in remote) result['${song['ytid']}'] = Map.from(song);
    for (final entry in edits.entries) {
      if (entry.value['liked'] == false) {
        result.remove(entry.key);
      } else if (entry.value['song'] is Map) {
        result[entry.key] = Map.from(entry.value['song']);
      }
    }
    return result.values.toList();
  }

  Future<void> rememberRemote(List<Map<String, dynamic>> remote) => _box.put(
    'youtubeKnownLikes',
    remote.map((song) => '${song['ytid']}').toList(),
  );
}
