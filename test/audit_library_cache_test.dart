import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musyn/services/playlists_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musyn-catalog-');
    Hive.init(directory.path);
    for (final box in ['user', 'cache', 'settings']) {
      await Hive.openBox(box);
    }
    onlinePlaylists.value = [];
    userPlaylists.value = [];
    userLikedPlaylists.value = [];
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'browsing remote playlists stays bounded without growing the static catalogue',
    () async {
      final originalSize = playlists.length;
      final response = {
        'musicPlaylistShelfRenderer': {
          'contents': [
            {
              'musicResponsiveListItemRenderer': {
                'playlistItemData': {'videoId': 'abcdefghijk'},
                'flexColumns': [
                  for (final text in ['Track', 'Artist'])
                    {
                      'musicResponsiveListItemFlexColumnRenderer': {
                        'text': {
                          'runs': [
                            {'text': text},
                          ],
                        },
                      },
                    },
                ],
              },
            },
          ],
        },
      };
      final client = MockClient(
        (_) async => http.Response(jsonEncode(response), 200),
      );
      await http.runWithClient(() async {
        for (var i = 0; i < 205; i++) {
          final id = 'PLaudit$i';
          // Exercise the former catalogue-append path as well as cold fetches.
          if (i < 3)
            onlinePlaylists.value = [
              ...onlinePlaylists.value,
              {'ytid': id, 'list': []},
            ];
          final result = await getPlaylistInfoForWidget(id);
          expect((result?['list'] as List).length, 1);
        }
      }, () => client);
      expect(playlists.length, originalSize);
      expect(onlinePlaylists.value.length, lessThanOrEqualTo(200));
      expect(onlinePlaylists.value.last['ytid'], 'PLaudit204');
    },
  );

  test(
    'completed unlike invalidates an earlier unresolved like and permits later updates',
    () async {
      const id = 'PLauditlike';
      final like = updatePlaylistLikeStatus(
        id,
        true,
        playlistData: {'ytid': id, 'title': 'Test'},
      );
      final unlike = updatePlaylistLikeStatus(id, false);
      await Future.wait([like, unlike]);
      expect(userLikedPlaylists.value, isEmpty);
      await updatePlaylistLikeStatus(
        id,
        true,
        playlistData: {'ytid': id, 'title': 'Test'},
      );
      expect(userLikedPlaylists.value.single['ytid'], id);
    },
  );
}
