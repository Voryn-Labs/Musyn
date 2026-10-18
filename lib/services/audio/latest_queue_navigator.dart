import 'dart:async';

/// Coalesces rapid navigation and stops waiting for superseded URL resolution.
/// The owner must also reject stale native installs through [invalidate].
class LatestQueueNavigator {
  LatestQueueNavigator({
    required this.load,
    required this.isValid,
    required this.invalidate,
    this.debounce = const Duration(milliseconds: 80),
  });
  final Future<void> Function(int) load;
  final bool Function(int) isValid;
  final void Function() invalidate;
  final Duration debounce;
  int? target;
  int _revision = 0;
  Completer<void>? _changed;
  Future<void>? _drain;
  bool get running => _drain != null;

  Future<void> select(int index) {
    if (!isValid(index)) return Future<void>.value();
    target = index;
    _revision++;
    invalidate();
    _wake();
    return _drain ??= _run().whenComplete(() {
      _drain = null;
      if (target != null) unawaited(select(target!));
    });
  }

  void cancel() {
    target = null;
    _revision++;
    invalidate();
    _wake();
  }

  void _wake() {
    if (_changed?.isCompleted == false) _changed!.complete();
  }

  Future<void> _run() async {
    while (target != null) {
      final index = target!;
      final revision = _revision;
      final changed = _changed = Completer<void>();
      await Future.any<void>([Future<void>.delayed(debounce), changed.future]);
      if (revision != _revision) continue;
      if (!isValid(index)) {
        target = null;
        break;
      }
      await Future.any<void>([load(index), changed.future]);
      if (revision == _revision) target = null;
    }
  }
}
