import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/download_transfer.dart';

void main() {
  test(
    'cancellation after completed races handles late errors safely',
    () async {
      final token = DownloadCancellation();
      for (var i = 0; i < 100; i++) {
        expect(await token.race(Future.value(i)), i);
      }
      final late = Completer<int>();
      final pending = token.race(late.future);
      final cancelled = expectLater(pending, throwsA(isA<DownloadCancelled>()));
      token.cancel();
      await cancelled;
      late.completeError(StateError('request failed after cancellation'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musyn-transfer-');
    file = File('${directory.path}/track.m4a');
  });
  tearDown(() => directory.delete(recursive: true));

  test('only a complete transfer replaces an existing offline asset', () async {
    await file.writeAsString('previous copy');
    await expectLater(
      writeDownloadAtomically(
        destination: file,
        bytes: Stream.value([1, 2]),
        expectedBytes: 3,
        minimumBytes: 1,
        cancellation: DownloadCancellation(),
      ),
      throwsA(isA<HttpException>()),
    );
    expect(await file.readAsString(), 'previous copy');
    expect(await File('${file.path}.part').exists(), isFalse);
  });

  test(
    'cancel interrupts a stalled transfer and removes its partial file',
    () async {
      final stream = StreamController<List<int>>();
      final cancellation = DownloadCancellation();
      final transfer = writeDownloadAtomically(
        destination: file,
        bytes: stream.stream,
        cancellation: cancellation,
      );
      final result = expectLater(transfer, throwsA(isA<DownloadCancelled>()));
      stream.add(List.filled(9000, 1));
      await Future<void>.delayed(Duration.zero);
      cancellation.cancel();
      await result;
      await stream.close();
      expect(await file.exists(), isFalse);
      expect(await File('${file.path}.part').exists(), isFalse);
    },
  );

  for (final received in [9500, 10500]) {
    test(
      'known 10000-byte transfer rejects $received bytes and keeps old audio',
      () async {
        await file.writeAsBytes(List.filled(10000, 7));
        await expectLater(
          writeDownloadAtomically(
            destination: file,
            bytes: Stream.value(List.filled(received, 1)),
            expectedBytes: 10000,
            cancellation: DownloadCancellation(),
          ),
          throwsA(isA<HttpException>()),
        );
        expect(await file.readAsBytes(), List.filled(10000, 7));
        expect(await File('${file.path}.part').exists(), isFalse);
      },
    );
  }

  test(
    'offline playback minimum is checked before replacing a saved copy',
    () async {
      final previous = List.filled(60000, 7);
      await file.writeAsBytes(previous);
      await expectLater(
        writeDownloadAtomically(
          destination: file,
          bytes: Stream.value(List.filled(40000, 1)),
          expectedBytes: 40000,
          minimumBytes: 51201,
          cancellation: DownloadCancellation(),
        ),
        throwsA(isA<HttpException>()),
      );
      expect(await file.readAsBytes(), previous);
    },
  );

  test('successful transfer commits the exact bytes', () async {
    final bytes = List.filled(9000, 7);
    final progress = <(int, int?)>[];
    await writeDownloadAtomically(
      destination: file,
      bytes: Stream.fromIterable([bytes.sublist(0, 4000), bytes.sublist(4000)]),
      onProgress: (received, total) => progress.add((received, total)),
      expectedBytes: bytes.length,
      cancellation: DownloadCancellation(),
    );
    expect(await file.readAsBytes(), bytes);
    expect(progress, [(4000, 9000), (9000, 9000)]);
  });
}
