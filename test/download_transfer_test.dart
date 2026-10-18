import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/download_transfer.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musified-transfer-');
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

  test('successful transfer commits the exact bytes', () async {
    final bytes = List.filled(9000, 7);
    await writeDownloadAtomically(
      destination: file,
      bytes: Stream.value(bytes),
      expectedBytes: bytes.length,
      cancellation: DownloadCancellation(),
    );
    expect(await file.readAsBytes(), bytes);
  });
}
