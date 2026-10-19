/// Pre-resolved stream URLs for upcoming queue items.
class AudioPreloadCache {
  static const int _maxStreamUrls = 30;

  final Map<String, Object> _inFlight = {};
  final Set<Object> _discarded = {};
  int get activeCount => _inFlight.length;
  Set<String> get preloadingYtIds => _inFlight.keys.toSet();
  final Set<String> preloadedYtIds = <String>{};
  final Map<String, String> streamUrls = <String, String>{};

  final Map<String, Map<String, dynamic>> streamMetadata = {};

  void reset() {
    _discarded.addAll(_inFlight.values);
    preloadedYtIds.clear();
    streamUrls.clear();
    streamMetadata.clear();
  }

  void drop(String ytid) {
    final pending = _inFlight[ytid];
    if (pending != null) _discarded.add(pending);
    preloadedYtIds.remove(ytid);
    streamUrls.remove(ytid);
    streamMetadata.remove(ytid);
  }

  Object? begin(String ytid, {required int maxConcurrent}) {
    if (_inFlight.containsKey(ytid) || activeCount >= maxConcurrent)
      return null;
    final ticket = Object();
    _inFlight[ytid] = ticket;
    return ticket;
  }

  /// Invalidating cached data does not cancel an already running request.
  /// Hold its concurrency slot until that request actually finishes.
  bool finish(String ytid, Object ticket) {
    if (!identical(_inFlight[ytid], ticket)) return false;
    _inFlight.remove(ytid);
    return !_discarded.remove(ticket);
  }

  /// Evict oldest entries when the cache exceeds its size limit.
  void trimIfNeeded() {
    while (streamUrls.length > _maxStreamUrls) {
      final oldest = streamUrls.keys.first;
      drop(oldest);
    }
  }
}
