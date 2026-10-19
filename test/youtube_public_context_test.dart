import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/services/youtube_public_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'public bootstrap is shared and caches the actual client version',
    () async {
      var requests = 0;
      final client = YouTubePublicContext();
      await http.runWithClient(
        () async {
          final versions = await Future.wait([
            client.version(),
            client.version(),
          ]);
          expect(versions, ['1.20261018.16.00', '1.20261018.16.00']);
          expect(await client.version(), versions.first);
          expect(requests, 1);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.headers.containsKey('Cookie'), isFalse);
          return http.Response(
            'ytcfg.set({"INNERTUBE_CLIENT_VERSION":"1.20261018.16.00"});',
            200,
          );
        }),
      );
    },
  );
  test(
    'charts use fresh public headers even with a signed-in session',
    () async {
      YouTubeAuthService().isSignedIn.value = true;
      final paths = <String>[];
      final fixture = File(
        'test/fixtures/youtube_charts_india.json',
      ).readAsStringSync();
      await http.runWithClient(
        () async {
          final charts = await Future.wait([
            YouTubeMusicSyncService().fetchChartPlaylists(country: 'IN'),
            YouTubeMusicSyncService().fetchChartPlaylists(country: 'IN'),
          ]).timeout(const Duration(seconds: 3));
          expect(charts.first, isNotEmpty);
          expect(charts.last, charts.first);
        },
        () => MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(request.headers.containsKey('Cookie'), isFalse);
          if (request.method == 'GET')
            return http.Response(
              '{"INNERTUBE_CLIENT_VERSION":"1.20261018.16.00"}',
              200,
            );
          expect(
            request.headers['X-Youtube-Client-Version'],
            '1.20261018.16.00',
          );
          final body = jsonDecode(request.body) as Map;
          expect(
            body['context']['client']['clientVersion'],
            '1.20261018.16.00',
          );
          expect(body['context']['client']['gl'], 'IN');
          expect(body['browseId'], 'FEmusic_charts');
          return http.Response.bytes(
            utf8.encode(fixture),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(paths.where((path) => path.contains('browse')).length, 1);
      YouTubeAuthService().isSignedIn.value = false;
    },
  );
}
