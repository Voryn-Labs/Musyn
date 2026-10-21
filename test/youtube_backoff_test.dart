import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/youtube_backoff.dart';
import 'package:musyn/services/common_services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/src/retry.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('a provider rate limit is not retried immediately', () async {
    var calls = 0;
    await expectLater(
      retry<void>(null, () {
        calls++;
        throw RequestLimitExceededException('test throttle');
      }),
      throwsA(isA<RequestLimitExceededException>()),
    );
    expect(calls, 1);
  });
  test('cooldown stops new requests and expires without another attempt', () {
    var time = DateTime(2026);
    final budget = YoutubeBackoff(now: () => time);
    expect(budget.active, false);
    budget.limited();
    expect(budget.active, true);
    time = time.add(const Duration(seconds: 31));
    expect(budget.active, false);
  });
  test(
    'real resolver stops on first HTTP 429 and closes its owned transport',
    () async {
      final client = ThrottledClient();
      await http.runWithClient(() async {
        expect(await fetchBestAudioStream('abcdefghijk'), isNull);
        expect(client.requests, 1);
        expect(client.closed, true);
        expect(youtubeStreamBackoff.active, true);
        expect(await fetchBestAudioStream('lmnopqrstuv'), isNull);
        expect(
          client.requests,
          1,
          reason: 'Cooldown must prevent more client/track attempts',
        );
      }, () => client);
    },
  );
}

class ThrottledClient extends MockClient {
  ThrottledClient()
    : super((request) async => http.Response('', 429, request: request));
  int requests = 0;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    return super.send(request);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}
