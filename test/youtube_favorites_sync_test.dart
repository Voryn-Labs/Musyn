import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musyn/services/library_state.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_favorites_store.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';

Map<String, dynamic> likedResponse(List<String> ids) => {
  'contents': {
    'musicPlaylistShelfRenderer': {
      'contents': [
        for (final id in ids)
          {
            'musicResponsiveListItemRenderer': {
              'playlistItemData': {'videoId': id},
              'flexColumns': [
                {
                  'musicResponsiveListItemFlexColumnRenderer': {
                    'text': {
                      'runs': [
                        {'text': 'Song $id'},
                      ],
                    },
                  },
                },
                {
                  'musicResponsiveListItemFlexColumnRenderer': {
                    'text': {
                      'runs': [
                        {'text': 'Artist'},
                      ],
                    },
                  },
                },
              ],
            },
          },
      ],
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  final service = YouTubeMusicSyncService();
  final store = YouTubeFavoritesStore();
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('musyn-favorite-sync-');
    Hive.init(dir.path);
    for (final box in ['user', 'youtube_auth', 'settings', 'cache']) {
      await Hive.openBox(box);
    }
    await Hive.box(
      'youtube_auth',
    ).put('cookies', {'SAPISID': 'fake-unit-test-cookie'});
    YouTubeAuthService().isSignedIn.value = true;
    ytAutoSyncLikes.value = true;
    ytAutoSyncPlaylists.value = false;
    offlineMode.value = false;
    userLikedSongsList.value = [];
    service.syncError.value = null;
  });
  tearDown(() async {
    YouTubeAuthService().isSignedIn.value = false;
    await Hive.close();
    await dir.delete(recursive: true);
  });
  http.Response jsonResponse(Map data, [int status = 200]) =>
      http.Response.bytes(
        utf8.encode(jsonEncode(data)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
  http.Response bootstrap() =>
      http.Response('{"INNERTUBE_CLIENT_VERSION":"1.20261018.16.00"}', 200);

  test(
    'VLLM collection uses authenticated Liked Music and never public playlist scraping',
    () async {
      var posts = 0;
      await http.runWithClient(
        () async {
          final playlist = await getPlaylistInfoForWidget('VLLM');
          expect(playlist!['title'], 'Liked Music');
          expect((playlist['list'] as List).single['ytid'], 'abcdefghijk');
          expect(posts, 1);
        },
        () => MockClient((request) async {
          if (request.method == 'GET') return bootstrap();
          posts++;
          expect(jsonDecode(request.body)['browseId'], 'VLLM');
          expect(request.headers['Authorization'], startsWith('SAPISIDHASH '));
          expect(
            request.headers['X-Youtube-Client-Version'],
            '1.20261018.16.00',
          );
          return jsonResponse(likedResponse(['abcdefghijk']));
        }),
      );
    },
  );

  test(
    'remote pull preserves local favorites and overlays pending unlike before upload',
    () async {
      userLikedSongsList.value = [
        {'ytid': '12345678901', 'title': 'Local favorite'},
        {'ytid': 'saavn_track_123', 'title': 'Local provider favorite'},
      ];
      await store.record('zyxwvutsrqp', false, null);
      final mutations = <String>[];
      await http.runWithClient(
        () async {
          expect(await service.fullSync(), isTrue);
          expect(
            userLikedSongsList.value.map((s) => s['ytid']),
            unorderedEquals(['abcdefghijk', '12345678901', 'saavn_track_123']),
          );
          expect(service.pendingLikes.value, 0);
          expect(
            mutations,
            containsAll(['like:12345678901', 'removelike:zyxwvutsrqp']),
          );
          expect(mutations.any((m) => m.contains('saavn')), isFalse);
        },
        () => MockClient((request) async {
          if (request.method == 'GET') return bootstrap();
          final body = jsonDecode(request.body);
          if (request.url.path.endsWith('/browse'))
            return jsonResponse(likedResponse(['abcdefghijk', 'zyxwvutsrqp']));
          mutations.add(
            '${request.url.path.split('/').last}:${body['target']['videoId']}',
          );
          return jsonResponse({});
        }),
      );
    },
  );

  test(
    'failed or unrecognized remote response cannot wipe saved favorites',
    () async {
      for (final status in [503, 200]) {
        userLikedSongsList.value = [
          {'ytid': 'abcdefghijk', 'title': 'Keep me'},
        ];
        await http.runWithClient(
          () async {
            expect(await service.fullSync(), isFalse);
            expect(userLikedSongsList.value.single['title'], 'Keep me');
            expect(store.pending['abcdefghijk']!['liked'], isTrue);
            expect(service.syncError.value, isNotNull);
          },
          () => MockClient(
            (request) async => request.method == 'GET'
                ? bootstrap()
                : jsonResponse({}, status),
          ),
        );
      }
    },
  );

  test(
    'stale acknowledgement and remote snapshot cannot undo newer heart taps',
    () async {
      await store.record('abcdefghijk', true, {'ytid': 'abcdefghijk'});
      final old = store.pending['abcdefghijk']!['revision'];
      await store.record('abcdefghijk', false, null);
      await store.acknowledge('abcdefghijk', old);
      expect(store.pending['abcdefghijk']!['sent'], isNull);
      final current = store.pending['abcdefghijk']!['revision'];
      await store.acknowledge('abcdefghijk', current);
      await store.confirmSnapshot([
        {'ytid': 'abcdefghijk'},
      ]);
      expect(
        store.merge([
          {'ytid': 'abcdefghijk'},
        ], []),
        isEmpty,
      );
      await Hive.box('user').close();
      await Hive.openBox('user');
      expect(store.pending['abcdefghijk']!['liked'], isFalse);
      await store.confirmSnapshot([]);
      expect(store.pending, isEmpty);
    },
  );

  test('signed-in Liked Music failure never retries anonymously', () async {
    var posts = 0;
    await http.runWithClient(
      () async {
        await expectLater(service.fetchLikedSongs(), throwsException);
        expect(posts, 1);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') return bootstrap();
        posts++;
        expect(request.headers['Authorization'], isNotNull);
        return jsonResponse({}, 403);
      }),
    );
  });
}
