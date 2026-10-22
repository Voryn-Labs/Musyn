import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/screens/artist_page.dart';
import 'package:musyn/screens/bottom_navigation_page.dart';
import 'package:musyn/screens/charts_page.dart';
import 'package:musyn/screens/downloads_page.dart';
import 'package:musyn/screens/explore_page.dart';
import 'package:musyn/screens/home_page.dart';
import 'package:musyn/screens/library_page.dart';
import 'package:musyn/screens/logs_page.dart';
import 'package:musyn/screens/playlist_folder_page.dart';
import 'package:musyn/screens/playlist_page.dart';
import 'package:musyn/screens/search_page.dart';
import 'package:musyn/screens/settings_page.dart';
import 'package:musyn/screens/smart_collection_page.dart';
import 'package:musyn/screens/smart_library_page.dart';
import 'package:musyn/screens/user_songs_page.dart';
import 'package:musyn/services/app_navigation_state.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/offline_search_placeholder.dart';

class NavigationManager {
  factory NavigationManager() {
    return _instance;
  }

  NavigationManager._internal() {
    _setupRouter();
  }

  void _setupRouter() {
    final routes = [
      GoRoute(
        path: settingsPath,
        pageBuilder: (context, state) =>
            _pushPage(child: const SettingsPage(), state: state),
        routes: [
          GoRoute(
            path: 'logs',
            pageBuilder: (context, state) =>
                _pushPage(child: const LogsPage(), state: state),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: parentNavigatorKey,
        branches: _getRouteBranches(),
        pageBuilder: (context, state, navigationShell) {
          return getPage(
            child: BottomNavigationPage(child: navigationShell),
            state: state,
          );
        },
      ),
    ];

    _router = GoRouter(
      navigatorKey: parentNavigatorKey,
      initialLocation: homePath,
      errorBuilder: (context, state) => CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Page unavailable'),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ContentState(
              icon: CupertinoIcons.link,
              title: 'This page is no longer available',
              message:
                  'The link may be incomplete or the collection may have moved.',
              actionLabel: 'Go to Home',
              onAction: () => context.go(homePath),
              secondaryLabel: 'Open library',
              onSecondary: () => context.go(libraryPath),
            ),
          ),
        ),
      ),
      routes: routes,
      restorationScopeId: 'router',
      debugLogDiagnostics: kDebugMode,
      routerNeglect: true,
      redirect: (context, state) {
        // Handle offline mode redirects
        final isOffline = offlineMode.value;
        final currentPath = state.matchedLocation;

        if (isOffline && currentPath.contains('/album/')) {
          // Releases are only browsable through YouTube Music.
          return homePath;
        }

        if (isOffline && currentPath.contains('/artist/')) {
          final artistId = state.pathParameters['artistId'] ?? '';
          if (!offlinePlaylistService.isPlaylistDownloaded(artistId)) {
            return homePath;
          }
        }

        return null; // No redirect needed
      },
    );
  }

  static final NavigationManager _instance = NavigationManager._internal();

  static NavigationManager get instance => _instance;

  static late final GoRouter _router;
  static GoRouter get router {
    final _ = _instance;
    return _router;
  }

  static final GlobalKey<NavigatorState> parentNavigatorKey = appNavigatorKey;
  static final GlobalKey<NavigatorState> homeTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> searchTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> libraryTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> exploreTabNavigatorKey =
      GlobalKey<NavigatorState>();

  BuildContext get context {
    final ctx = router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) {
      throw StateError(
        'NavigationManager.context was accessed before the navigator context was available.',
      );
    }
    return ctx;
  }

  GoRouterDelegate get routerDelegate => router.routerDelegate;

  GoRouteInformationParser get routeInformationParser =>
      router.routeInformationParser;

  static const String homePath = NavigationPaths.homePath;
  static const String explorePath = NavigationPaths.explorePath;
  static const String settingsPath = '/settings';
  static const String searchPath = NavigationPaths.searchPath;
  static const String libraryPath = NavigationPaths.libraryPath;

  /// Refresh the router configuration when offline mode changes
  static void refreshRouter() {
    // Force router to re-evaluate redirect logic
    router.refresh();
  }

  List<StatefulShellBranch> _getRouteBranches() {
    // Always return all branches, but handle visibility in the UI
    return [
      // Branch 0: Home
      StatefulShellBranch(
        navigatorKey: homeTabNavigatorKey,
        routes: [
          GoRoute(
            path: homePath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(
                child: ValueListenableBuilder<bool>(
                  valueListenable: offlineMode,
                  builder: (context, isOffline, _) {
                    return isOffline
                        ? const UserSongsPage(page: 'offline')
                        : const HomePage();
                  },
                ),
                state: state,
              );
            },
            routes: [
              GoRoute(
                path: 'library',
                pageBuilder: (context, state) =>
                    _pushPage(child: const LibraryPage(), state: state),
              ),
              _downloadsRoute(),
              _chartsRoute(),
              _playlistRoute(),
              _artistRoute(),
              _albumRoute(),
              _folderRoute(),
            ],
          ),
        ],
      ),
      // Branch 1: Explore
      StatefulShellBranch(
        navigatorKey: exploreTabNavigatorKey,
        routes: [
          GoRoute(
            path: explorePath,
            pageBuilder: (context, state) =>
                getPage(child: const ExplorePage(), state: state),
            routes: [
              GoRoute(
                path: 'category',
                pageBuilder: (context, state) => _pushPage(
                  child: ExplorePage(
                    category:
                        _extraAsMap(state.extra)?.cast<String, dynamic>() ??
                        {
                          'browseId': state.uri.queryParameters['id'],
                          'params': state.uri.queryParameters['params'],
                          'title':
                              state.uri.queryParameters['title'] ?? 'Category',
                        },
                  ),
                  state: state,
                ),
              ),
              _artistRoute(),
              _albumRoute(),
              _downloadsRoute(),
              _chartsRoute(),
              _playlistRoute(),
              _folderRoute(),
            ],
          ),
        ],
      ),
      // Branch 2: Library
      StatefulShellBranch(
        navigatorKey: libraryTabNavigatorKey,
        routes: [
          GoRoute(
            path: libraryPath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(child: const LibraryPage(), state: state);
            },
            routes: [
              GoRoute(
                path: 'smart',
                pageBuilder: (context, state) =>
                    _pushPage(child: const SmartLibraryPage(), state: state),
                routes: [
                  GoRoute(
                    path: ':collectionId',
                    pageBuilder: (context, state) => _pushPage(
                      child: SmartCollectionPage(
                        collectionId:
                            state.pathParameters['collectionId'] ?? '',
                        collection:
                            state.extra is Map ? state.extra as Map : null,
                      ),
                      state: state,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'userSongs/:page',
                pageBuilder: (context, state) => _pushPage(
                  child: UserSongsPage(
                    page: state.pathParameters['page'] ?? 'liked',
                  ),
                  state: state,
                ),
              ),
              _artistRoute(),
              _albumRoute(),
              _downloadsRoute(),
              _chartsRoute(),
              _playlistRoute(),
              _folderRoute(),
            ],
          ),
        ],
      ),
      // Branch 3: Search
      StatefulShellBranch(
        navigatorKey: searchTabNavigatorKey,
        routes: [
          GoRoute(
            path: searchPath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(
                child: ValueListenableBuilder<bool>(
                  valueListenable: offlineMode,
                  builder: (context, isOffline, _) {
                    return isOffline
                        ? const OfflineSearchPlaceholder()
                        : SearchPage(
                            initialQuery: state.uri.queryParameters['q'],
                          );
                  },
                ),
                state: state,
              );
            },
            routes: [
              _artistRoute(),
              _albumRoute(),
              _downloadsRoute(),
              _chartsRoute(),
              _playlistRoute(),
              _folderRoute(),
            ],
          ),
        ],
      ),
    ];
  }

  GoRoute _downloadsRoute() => GoRoute(
    path: 'downloads',
    pageBuilder: (context, state) =>
        _pushPage(child: const DownloadsPage(), state: state),
  );

  GoRoute _chartsRoute() => GoRoute(
    path: 'charts',
    pageBuilder: (context, state) =>
        _pushPage(child: const ChartsPage(), state: state),
  );

  GoRoute _playlistRoute() => GoRoute(
    path: 'playlist/:playlistId',
    pageBuilder: (context, state) => _pushPage(
      child: PlaylistPage(
        playlistId: state.pathParameters['playlistId'] ?? '',
        playlistData: state.extra,
      ),
      state: state,
    ),
  );

  GoRoute _folderRoute() => GoRoute(
    path: 'folder/:folderId/:folderName',
    pageBuilder: (context, state) => _pushPage(
      child: PlaylistFolderPage(
        folderId: state.pathParameters['folderId'] ?? '',
        folderName: state.pathParameters['folderName'] ?? '',
      ),
      state: state,
    ),
  );

  /// The artist landing page, plus the full song catalog of the artist.
  GoRoute _artistRoute() {
    return GoRoute(
      path: 'artist/:artistId',
      pageBuilder: (context, state) => _pushPage(
        child: ArtistPage(
          artistId: state.pathParameters['artistId'] ?? '',
          artistData: _extraAsMap(state.extra),
        ),
        state: state,
      ),
      routes: [
        GoRoute(
          path: 'songs',
          pageBuilder: (context, state) => _pushPage(
            child: PlaylistPage(
              playlistId: state.pathParameters['artistId'] ?? '',
              playlistData: _extraAsMap(state.extra),
              cubeIcon: CupertinoIcons.person_crop_circle_fill,
              isArtist: true,
            ),
            state: state,
          ),
        ),
      ],
    );
  }

  /// A release opened from an artist page. YouTube Music browses a release the
  /// way it browses a playlist, so the playlist page shows it as it is.
  GoRoute _albumRoute() {
    return GoRoute(
      path: 'album/:albumId',
      pageBuilder: (context, state) => _pushPage(
        child: PlaylistPage(
          playlistId: state.pathParameters['albumId'] ?? '',
          playlistData: _extraAsMap(state.extra),
          cubeIcon: CupertinoIcons.music_albums,
        ),
        state: state,
      ),
    );
  }

  static Map? _extraAsMap(Object? extra) {
    if (extra is Map) return Map<String, dynamic>.from(extra);
    return null;
  }

  static Page<void> getPage({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  static Page<void> _pushPage({
    required Widget child,
    required GoRouterState state,
  }) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
}
