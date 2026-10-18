import 'dart:async';

/// Orders mutations of a shared native resource without serializing resolution.
/// An operation's failure is delivered to its caller, not to the next operation.
class AsyncOperationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        released.complete();
      }
    }();
  }
}
