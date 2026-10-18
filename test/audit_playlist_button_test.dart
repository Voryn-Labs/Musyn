import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/widgets/playlist_page/add_to_playlist_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musified-batch-');
    Hive.init(directory.path);
    await Hive.openBox('user');
    YouTubeAuthService().isSignedIn.value = false;
    userCustomPlaylists.value = [
      {
        'ytid': 'custom-target',
        'title': 'Target',
        'source': 'user-created',
        'list': <dynamic>[],
      },
    ];
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('playlist add button adds the full batch and deduplicates', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: PlaylistAddToPlaylistButton(
              resolvePlaylist: () async => {
                'list': [
                  {'ytid': 'a', 'title': 'First'},
                  {'ytid': 'b', 'title': 'Second'},
                  {'ytid': 'a', 'title': 'Duplicate'},
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CupertinoButton).first);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('My · Target'));
      await Hive.box('user').flush();
    });
    await tester.pumpAndSettle();
    expect(
      (userCustomPlaylists.value.single['list'] as List).map(
        (song) => song['ytid'],
      ),
      ['a', 'b'],
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
