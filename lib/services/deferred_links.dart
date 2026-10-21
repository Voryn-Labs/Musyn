import 'dart:async';

/// Bounded cold-start inbox, drained only after the real navigator is mounted.
class DeferredLinks {
  DeferredLinks(this.handle, {this.capacity = 8});
  final Future<void> Function(Uri) handle;
  final int capacity;
  final _queued = <Uri>[];
  final _known = <Uri>{};
  bool _ready = false;
  bool _draining = false;
  Future<void> pending = Future.value();
  void receive(Uri uri) {
    if (_known.contains(uri) || _known.length >= capacity) return;
    _known.add(uri);
    _queued.add(uri);
    _drain();
  }

  void attach() {
    _ready = true;
    _drain();
  }

  void detach() {
    _ready = false;
  }

  void _drain() {
    if (!_ready || _draining) return;
    _draining = true;
    pending = () async {
      try {
        while (_ready && _queued.isNotEmpty) {
          final uri = _queued.removeAt(0);
          try {
            await handle(uri);
          } finally {
            _known.remove(uri);
          }
        }
      } finally {
        _draining = false;
      }
    }();
    unawaited(pending.catchError((Object _) {}));
  }
}
