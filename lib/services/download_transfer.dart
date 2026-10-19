import 'dart:async';
import 'dart:io';

class DownloadCancelled implements Exception {}

class DownloadCancellation {
  final _listeners = <void Function()>{};
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() {
    if (isCancelled) return;
    _isCancelled = true;
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  void check() {
    if (isCancelled) throw DownloadCancelled();
  }

  Future<T> race<T>(Future<T> operation) {
    final result = Completer<T>();
    void onCancel() {
      if (!result.isCompleted) result.completeError(DownloadCancelled());
    }

    if (isCancelled) {
      onCancel();
    } else {
      _listeners.add(onCancel);
    }
    operation.then(
      (value) {
        _listeners.remove(onCancel);
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        _listeners.remove(onCancel);
        if (!result.isCompleted) result.completeError(error, stackTrace);
      },
    );
    return result.future;
  }
}

/// A failed or cancelled transfer never exposes a partial offline audio file.
Future<void> writeDownloadAtomically({
  required File destination,
  required Stream<List<int>> bytes,
  required DownloadCancellation cancellation,
  int? expectedBytes,
  void Function(int received, int? total)? onProgress,
  int minimumBytes = 8193,
  Duration idleTimeout = const Duration(seconds: 20),
}) async {
  cancellation.check();
  final temporary = File('${destination.path}.part');
  await destination.parent.create(recursive: true);
  final sink = temporary.openWrite();
  final iterator = StreamIterator(bytes);
  var received = 0;
  try {
    while (await cancellation.race(iterator.moveNext().timeout(idleTimeout))) {
      cancellation.check();
      final chunk = iterator.current;
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, expectedBytes);
    }
    await sink.flush();
    await sink.close();
    cancellation.check();
    if (received < minimumBytes) {
      throw const HttpException('Incomplete audio download: payload too small');
    }
    if (expectedBytes != null &&
        expectedBytes > 0 &&
        received < (expectedBytes * 0.90)) {
      throw const HttpException('Incomplete audio download: truncated stream');
    }
    await temporary.rename(destination.path);
  } finally {
    await iterator.cancel();
    try {
      await sink.close();
    } catch (_) {}
    if (await temporary.exists()) await temporary.delete();
  }
}
