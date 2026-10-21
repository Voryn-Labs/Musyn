/// Joins concurrent requests from the player and lock screen. Completed misses
/// are retried on a later request; old tracks cannot overwrite newer UI state.
class LyricsRequestCache {
  LyricsRequestCache(this.load);
  final Future<String?> Function(String artist, String title) load;
  final _pending = <String, Future<String?>>{};
  Future<String?> fetch(String artist, String title) {
    final key = '$artist\n$title';
    final existing = _pending[key];
    if (existing != null) return existing;
    late final Future<String?> request;
    request = Future<String?>.sync(() => load(artist, title)).whenComplete(() {
      if (identical(_pending[key], request)) _pending.remove(key);
    });
    _pending[key] = request;
    return request;
  }
}
