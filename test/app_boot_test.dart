import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musyn/main.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/playlist_sharing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('musyn_test_');
    Hive.init(tempDir.path);
    for (final box in [
      'settings',
      'user',
      'favorite_stations',
      'favorite_playlists',
      'search_history',
      'cache',
      'saavn_match_cache',
    ]) {
      await Hive.openBox(box);
    }
    reloadSettingsFromStorage();
  });

  testWidgets('App boots without null check errors or exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(const Musyn());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Let bounded catalogue requests fail/complete before disposing the app.
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();

    expect(find.byType(Musyn), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'playlist received during splash imports after the navigator mounts',
    (tester) async {
      userCustomPlaylists.value = [];
      final encoded = PlaylistSharingService.encodePlaylist({
        'title': 'Cold launch',
        'list': [],
      });
      await handleIncomingLink(Uri.parse('musyn://playlist/custom/$encoded'));
      expect(userCustomPlaylists.value, isEmpty);
      await tester.pumpWidget(const Musyn());
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      expect(userCustomPlaylists.value.single['title'], 'Cold launch');
      expect(tester.takeException(), isNull);
    },
  );
}
