import 'package:musyn/utilities/async_operation_queue.dart';

/// Serializes read/modify/persist/publish across concurrent download workers.
class OfflineSongRegistry {
  OfflineSongRegistry({
    required this.read,
    required this.persist,
    required this.publish,
  });

  final List<dynamic> Function() read;
  final Future<void> Function(List<dynamic>) persist;
  final void Function(List<dynamic>) publish;
  final _updates = AsyncOperationQueue();

  Future<void> upsert(Map song) => _updates.run(() async {
    final songs = List<dynamic>.from(read());
    final index = songs.indexWhere((entry) => entry['ytid'] == song['ytid']);
    if (index < 0) {
      songs.add(song);
    } else {
      songs[index] = song;
    }
    await persist(songs);
    publish(songs);
  });

  Future<void> remove(dynamic id) => _updates.run(() async {
    final songs = List<dynamic>.from(read())
      ..removeWhere((entry) => entry['ytid'] == id);
    await persist(songs);
    publish(songs);
  });
}
