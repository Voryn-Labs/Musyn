import 'package:musified/utilities/queue_entry_utils.dart';

/// Mutable queue/history state for [MusifiedAudioHandler].
/// Centralizes index bounds checks so queue bugs are easier to trace.
class AudioQueueState {
  static const int maxHistorySize = 50;

  final List<Map> items = [];
  final List<Map> originalItems = [];
  final List<Map> history = [];
  final QueueEntryIdManager entryIds = QueueEntryIdManager();

  int currentIndex = 0;

  int _loadingIndex = -1;
  String? _loadingKey;

  int get loadingIndex => _loadingIndex;
  set loadingIndex(int value) {
    _loadingIndex = value;
    if (value < 0) _loadingKey = null;
  }

  /// Identifies the track currently loading, so an index alone cannot be
  /// mistaken for "the same request" after the queue is replaced.
  String? get loadingKey => _loadingKey;

  void markLoading(int index, Map? song) {
    loadingIndex = index;
    _loadingKey = songKey(song);
  }

  static String? songKey(Map? song) {
    if (song == null) return null;
    final entryId = song['queueEntryId']?.toString();
    if (entryId != null && entryId.isNotEmpty) return entryId;
    final ytid = song['ytid']?.toString();
    return (ytid == null || ytid.isEmpty) ? null : ytid;
  }

  bool containsIndex(int index) => index >= 0 && index < items.length;

  Map? songAt(int index) => containsIndex(index) ? items[index] : null;

  Map? get currentSong => songAt(currentIndex);

  void addToHistory(Map song) {
    history.insert(0, song);
    if (history.length > maxHistorySize) {
      history.removeRange(maxHistorySize, history.length);
    }
  }
}
