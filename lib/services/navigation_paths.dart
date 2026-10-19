import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class NavigationPaths {
  static const String homePath = '/home';
  static const String explorePath = '/explore';
  static const String searchPath = '/search';
  static const String libraryPath = '/library';
  static String downloadsPath(BuildContext context) =>
      '${basePathFor(context)}/downloads';
  static String chartsPath(BuildContext context) =>
      '${basePathFor(context)}/charts';
  static String playlistPath(BuildContext context, String playlistId) =>
      '${basePathFor(context)}/playlist/${Uri.encodeComponent(playlistId)}';

  static String folderPath(
    BuildContext context,
    String folderId,
    String name,
  ) =>
      '${basePathFor(context)}/folder/${Uri.encodeComponent(folderId)}/${Uri.encodeComponent(name)}';

  /// Path of the page of an artist, inside the tab [context] belongs to.
  static String artistPath(BuildContext context, String artistId) =>
      '${basePathFor(context)}/artist/${Uri.encodeComponent(artistId)}';

  /// Path of the songs of an artist, i.e. of its "All songs" playlist.
  static String artistSongsPath(BuildContext context, String artistId) =>
      '${artistPath(context, artistId)}/songs';

  /// Path of the page of a YouTube Music release.
  static String albumPath(BuildContext context, String albumId) =>
      '${basePathFor(context)}/album/${Uri.encodeComponent(albumId)}';

  /// The tab a sub page pushed from [context] belongs to, so that artists,
  /// albums and playlists stay inside the tab they were opened from.
  static String basePathFor(BuildContext context) {
    try {
      final currentPath = GoRouterState.of(context).uri.path;
      if (currentPath.startsWith(explorePath)) return explorePath;
      if (currentPath.startsWith(searchPath)) return searchPath;
      if (currentPath.startsWith(libraryPath)) return libraryPath;
    } catch (_) {}

    return homePath;
  }
}
