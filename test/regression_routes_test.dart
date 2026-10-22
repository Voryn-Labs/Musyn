import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/router_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('playlist and folder destinations exist inside every browsing tab', () {
    final router = NavigationManager.router;
    for (final tab in ['home', 'explore', 'search', 'library']) {
      for (final destination in ['charts', 'downloads']) {
        expect(
          router.configuration.findMatch(Uri.parse('/$tab/$destination')).error,
          isNull,
        );
      }
      final playlist = router.configuration.findMatch(
        Uri.parse('/$tab/playlist/PLexample'),
      );
      expect(playlist.error, isNull);
      expect(playlist.pathParameters['playlistId'], 'PLexample');
      final folder = router.configuration.findMatch(
        Uri.parse('/$tab/folder/id-1/50%25%20Favourites'),
      );
      expect(folder.error, isNull);
      expect(folder.pathParameters['folderName'], '50% Favourites');
    }
  });
}
