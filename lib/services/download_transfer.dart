import 'dart:async';
import 'dart:io';

class DownloadCancelled implements Exception {}

class DownloadCancellation {
  final Completer<void> _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void check() {
    if (isCancelled) throw DownloadCancelled();
  }

  Future<T> race<T>(Future<T> operation) {
    return Future.any([
      operation,
      _cancelled.future.then<T>((_) => throw DownloadCancelled()),
    ]);
  }
}

/// A failed or cancelled transfer never exposes a partial offline audio file.
Future<void> writeDownloadAtomically({
  required File destination,
  required Stream<List<int>> bytes,
  required DownloadCancellation cancellation,
  int? expectedBytes,
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
    }
    await sink.flush();
    await sink.close();
    cancellation.check();
    if (received < minimumBytes ||
        (expectedBytes != null && received != expectedBytes)) {
      throw const HttpException('Incomplete audio download');
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
