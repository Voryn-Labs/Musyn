import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/services/ytdlp_client_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musyn-mutations-');
    Hive.init(directory.path);
    final box = await Hive.openBox('youtube_auth');
    await Hive.openBox('settings');
    await box.put('cookies', {'SAPISID': 'fake-test-cookie'});
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'client sync sends an explicit GitHub user agent and records commit metadata',
    () async {
      http.Request? githubRequest;
      final client = MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          githubRequest = request;
          return http.Response('{"sha":"0123456789abcdef"}', 200);
        }
        return http.Response("""
INNERTUBE_CLIENTS = {
    'visionos': {
        'INNERTUBE_CONTEXT': {
            'client': {
                'clientName': 'VISIONOS',
                'clientVersion': '1.02',
            },
        },
    },
}
""", 200);
      });
      final result = await http.runWithClient(
        () => YtdlpClientSyncService.instance.syncFromYtdlp(),
        () => client,
      );
      expect(result.ok, isTrue);
      expect(result.commit, '0123456');
      expect(githubRequest?.headers['User-Agent'], 'Musyn-App');
    },
  );

  test(
    'playlist mutations use valid API paths and ordered batch actions',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'playlistId': 'PLcreated'}), 200);
      });
      await http.runWithClient(() async {
        final service = YouTubeMusicSyncService();
        expect(await service.createUserPlaylist('New playlist'), 'PLcreated');
        expect(
          await service.addVideosToPlaylist('VLPLtarget', [
            'abcdefghijk',
            'lmnopqrstuv',
            'abcdefghijk',
          ]),
          2,
        );
      }, () => client);
      expect(requests.map((request) => request.url.path), [
        '/youtubei/v1/playlist/create',
        '/youtubei/v1/browse/edit_playlist',
      ]);
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['playlistId'], 'PLtarget');
      expect(
        (body['actions'] as List).map((action) => action['addedVideoId']),
        ['abcdefghijk', 'lmnopqrstuv'],
      );
    },
  );

  test('batch reports completed chunks if a later chunk fails', () async {
    var calls = 0;
    final client = MockClient(
      (_) async => http.Response('{}', ++calls == 1 ? 200 : 500),
    );
    final ids = List.generate(51, (index) => index.toString().padLeft(11, '0'));
    final added = await http.runWithClient(
      () => YouTubeMusicSyncService().addVideosToPlaylist('PLtarget', ids),
      () => client,
    );
    expect(added, 50);
  });
}
