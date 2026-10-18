import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/router_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('playlist and folder destinations exist inside every browsing tab', () {
    final router = NavigationManager.router;
    for (final tab in ['home', 'search', 'library']) {
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
