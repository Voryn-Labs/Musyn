/// Shares pending provider lookups between queue warming and a foreground tap.
/// Cancellation belongs to each caller; identity and source pins stay local.
class StreamResolutionPool {
  final _pending = <Object, Future<(String?, Map)>>{};

  Future<String?> resolve(
    Object key,
    Map song,
    Future<String?> Function(Map) lookup, {
    bool Function()? abandon,
  }) async {
    if (abandon?.call() == true) return null;
    var request = _pending[key];
    if (request == null) {
      final copy = Map.from(song);
      request = Future.sync(() => lookup(copy)).then((url) => (url, copy));
      _pending[key] = request;
    }
    try {
      final (url, resolved) = await request;
      if (abandon?.call() == true) return null;
      if (url != null) {
        for (final entry in resolved.entries) {
          if (entry.key.toString().startsWith('resolved') ||
              const ['duration', 'highResImage', 'image'].contains(entry.key)) {
            song[entry.key] = entry.value;
          }
        }
      }
      return url;
    } finally {
      if (identical(_pending[key], request)) {
        final _ = _pending.remove(key);
      }
    }
  }
}
