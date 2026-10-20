import 'package:musyn/services/motion_artwork.dart';
import 'package:musyn/widgets/ios26_surface.dart';
import 'package:musyn/screens/legal_page.dart';
import 'package:musyn/screens/logs_page.dart';
import 'package:musyn/screens/provider_access_page.dart';
import 'package:musyn/services/provider_access.dart';
import 'package:musyn/services/logger_service.dart';
import 'helpers/provider_fixture.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/widgets/musyn_bootstrap.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/widgets/download_picker_sheet.dart';
import 'package:musyn/widgets/now_playing/source_picker_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/utilities/playlist_dialogs.dart';
import 'package:musyn/services/discovery_state.dart';
import 'package:musyn/services/download_transfer.dart';
import 'package:musyn/services/download_activity.dart';
import 'package:musyn/screens/user_songs_page.dart';
import 'package:musyn/screens/settings_page.dart';
import 'package:musyn/screens/onboarding_page.dart';
import 'package:musyn/screens/playlist_folder_page.dart';
import 'package:musyn/screens/artist_page.dart';
import 'package:musyn/screens/playlist_page.dart';
import 'package:musyn/screens/downloads_page.dart';
import 'package:musyn/screens/charts_page.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/models/full_player_state.dart';
import 'package:musyn/models/position_data.dart';
import 'package:musyn/screens/bottom_navigation_page.dart';
import 'package:musyn/screens/now_playing_page.dart';
import 'package:musyn/screens/home_page.dart';
import 'package:musyn/screens/explore_page.dart';
import 'package:musyn/screens/library_page.dart';
import 'package:musyn/screens/search_page.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/audio/playback_controller.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/widgets/mini_player.dart';
import 'package:musyn/widgets/song_artwork.dart';
import 'package:musyn/widgets/player_sheet_route.dart';
import 'playback_install_test.dart' show ControlledPlayer;

class UiPlayback extends PlaybackController {
  UiPlayback() {
    audioPlayer.positionValue = const Duration(seconds: 42);
    mediaItem.add(
      const MediaItem(
        id: 'fixture',
        title: 'Midnight in motion',
        artist: 'Musyn Sessions',
        duration: Duration(minutes: 3),
        extras: {'ytid': 'fixture', 'resolvedSource': 'youtube'},
      ),
    );
    playbackState.add(
      PlaybackState(playing: true, processingState: AudioProcessingState.ready),
    );
  }
  @override
  final ControlledPlayer audioPlayer = ControlledPlayer();
  @override
  final currentPlayingYtid = ValueNotifier<String?>('fixture');
  @override
  final queueItemCount = ValueNotifier<int>(1);
  @override
  int get currentQueueIndex => 0;
  @override
  bool get hasNext => true;
  @override
  bool get hasPrevious => true;
  int next = 0;
  @override
  void clearPinnedSources() {}
  @override
  void clearPreparedStreams() {}
  Map? playedPlaylist;
  int? playedIndex;
  @override
  Future<void> playPlaylistSong({Map? playlist, required int songIndex}) async {
    playedPlaylist = playlist;
    playedIndex = songIndex;
  }

  @override
  Future<void> skipToNext() async {
    next++;
  }

  @override
  Stream<List<Map>> get queueAsMapStream => Stream.value([
    {
      'ytid': 'fixture',
      'title': 'Midnight in motion',
      'artist': 'Musyn Sessions',
    },
  ]);
  @override
  Stream<PositionData> get positionDataStream => Stream.value(
    PositionData(
      const Duration(seconds: 42),
      const Duration(minutes: 2),
      const Duration(minutes: 3),
    ),
  );
  Stream<FullPlayerState>? stateUpdates;
  @override
  Stream<FullPlayerState> get fullPlayerStateStream =>
      stateUpdates ??
      Stream.value(
        FullPlayerState(
          mediaItem: mediaItem.value,
          playbackState: playbackState.value,
          queue: [],
          position: PositionData(
            const Duration(seconds: 42),
            const Duration(minutes: 2),
            const Duration(minutes: 3),
          ),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory stateDirectory;
  setUpAll(() async {
    stateDirectory = await Directory.systemTemp.createTemp('musyn-ui-');
    Hive.init(stateDirectory.path);
    for (final box in ['user', 'settings', 'cache']) {
      await Hive.openBox(box, bytes: Uint8List(0));
    }
    // Linux has no San Francisco font. Load a licensed readable fallback
    // instead of Ahem's square glyphs, which distort every label's width.
    const portableFont = bool.fromEnvironment('MUSYN_PORTABLE_FONT');
    final systemFont = File('/System/Library/Fonts/SFNS.ttf');
    final font = !portableFont && systemFont.existsSync()
        ? systemFont
        : File('test/fixtures/fonts/Roboto-Regular.ttf');
    {
      final bytes = await font.readAsBytes();
      for (final family in [
        '.SF Pro Text',
        '.SF Pro Display',
        '.SF UI Text',
        '.SF UI Display',
        'CupertinoSystemText',
        'CupertinoSystemDisplay',
      ]) {
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }
    }
    final monospace = File('/System/Library/Fonts/Menlo.ttc');
    final monoLoader = FontLoader('Menlo')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await (monospace.existsSync()
                    ? monospace
                    : File('test/fixtures/fonts/Roboto-Regular.ttf'))
                .readAsBytes(),
          ),
        ),
      );
    await monoLoader.load();
    final icon = await rootBundle.load(
      'packages/cupertino_icons/assets/CupertinoIcons.ttf',
    );
    final loader = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(Future.value(icon));
    await loader.load();
  });
  tearDownAll(() async {
    await Hive.close();
    await stateDirectory.delete(recursive: true);
  });
  late UiPlayback handler;
  setUp(() async {
    await configureFixtureProvider();
    ios26Design.value = false;
    motionArtworkEnabled.value = false;
    MotionArtwork.instance.supported = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
    offlineMode.value = false;
    userRecentlyPlayed.value = [];
    trendingSongs.value = [];
    userLikedSongsList.value = [];
    userOfflineSongs.value = [];
    userCustomPlaylists.value = [];
    userPlaylistFolders.value = [];
    userPlaylists.value = [];
    userLikedPlaylists.value = [];
    pinnedPlaylistIds.value = [];
    saavnCharts.value = [];
    ytChartPlaylists.value = [];
    searchHistoryNotifier.value = [];
    for (final job in downloadActivity.jobs.value) {
      downloadActivity.finish(job.id, false);
    }
    downloadActivity.clearFinished();
    handler = UiPlayback();
    audioHandlerInstance = handler;
  });
  tearDown(() async {
    audioHandlerInstance = null;
    await handler.audioPlayer.dispose();
  });

  Future<void> render(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.dark,
    double scale = 1,
    bool reduceMotion = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CupertinoApp(
        theme: buildCupertinoTheme(brightness: brightness),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('capture'),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
        ),
        home: child,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('MUSYN_RENDER_UI')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('docs/ui-review')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('iPhone safe areas reserve content above player and tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => BottomNavigationPage(child: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => HomePage(loadFeed: () async {}),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/explore',
                  builder: (_, _) => ExplorePage(
                    loadCategories: () async => [
                      for (final name in [
                        'Chill',
                        'Commute',
                        'Energize',
                        'Feel good',
                        'Focus',
                        'Gaming',
                        'Party',
                        'Romance',
                        'Sad',
                        'Sleep',
                      ])
                        {'title': name, 'browseId': name},
                    ],
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (_, _) => const LibraryPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp.router(
        routerConfig: router,
        theme: buildCupertinoTheme(brightness: Brightness.dark),
        builder: (_, child) =>
            RepaintBoundary(key: const ValueKey('capture'), child: child!),
      ),
    );
    await tester.pumpAndSettle();
    for (final glass in [false, true]) {
      MotionArtwork.instance.supported = glass;
      ios26Design.value = glass;
      await tester.pump();
      for (final path in ['/', '/explore', '/library', '/search']) {
        router.go(path);
        await tester.pumpAndSettle();
        final viewport = find.descendant(
          of: find.byType(BottomNavigationPage),
          matching: find.byType(StatefulNavigationShell),
        );
        expect(
          tester.getBottomRight(viewport).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(MiniPlayer)).dy),
        );
        expect(
          tester.getBottomRight(find.byType(BitChordTabBar)).dy,
          lessThanOrEqualTo(840),
        );
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'iphone-${path == '/' ? 'home' : path.substring(1)}-${glass ? 'glass' : 'standard'}-dark',
        );
        if (glass) {
          final surface = find.byType(Ios26Surface);
          expect(tester.getSize(surface).height, 54);
          expect(
            tester.getTopLeft(surface).dy,
            greaterThanOrEqualTo(
              tester.getBottomRight(find.byType(MiniPlayer)).dy,
            ),
          );
          expect(tester.getBottomRight(surface).dy, lessThanOrEqualTo(836));
          expect(
            find.descendant(of: surface, matching: find.byType(MiniPlayer)),
            findsNothing,
          );
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('four reference tabs select by tap and drag', (tester) async {
    var selected = 0;
    await render(
      tester,
      CupertinoPageScaffold(
        child: Center(
          child: BitChordTabBar(
            selectedIndex: 0,
            onSelect: (index) => selected = index,
          ),
        ),
      ),
    );
    for (final label in ['Home', 'Explore', 'Library', 'Search']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Explore'));
    expect(selected, 1);
    await tester.drag(
      find.text('Home'),
      tester.getCenter(find.text('Search')) -
          tester.getCenter(find.text('Home')),
    );
    expect(selected, 3);
    await capture(tester, 'navigation-dark');
  });

  testWidgets(
    'mini-player refreshes same-track artwork after position updates',
    (tester) async {
      final updates = StreamController<FullPlayerState>.broadcast();
      handler.stateUpdates = updates.stream;
      addTearDown(() async {
        await updates.close();
      });
      void emit(MediaItem item, int seconds) => updates.add(
        FullPlayerState(
          mediaItem: item,
          playbackState: handler.playbackState.value,
          queue: [],
          position: PositionData(
            Duration(seconds: seconds),
            Duration.zero,
            item.duration ?? Duration.zero,
          ),
        ),
      );
      await render(
        tester,
        const CupertinoPageScaffold(child: Center(child: MiniPlayer())),
      );
      final original = handler.mediaItem.value!;
      emit(original, 43);
      await tester.pump();
      emit(original, 44);
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<SongArtworkWidget>(find.byType(SongArtworkWidget))
            .metadata,
        same(original),
      );
      final refreshed = original.copyWith(
        artUri: Uri.parse('file:///nonexistent-refreshed-artwork.jpg'),
      );
      expect(refreshed, original); // audio_service equality compares only IDs.
      emit(refreshed, 45);
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<SongArtworkWidget>(find.byType(SongArtworkWidget))
            .metadata,
        same(refreshed),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('native glass recreates its material when appearance changes', (
    tester,
  ) async {
    MotionArtwork.instance.supported = true;
    ios26Design.value = true;
    final creations = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create')
            creations.add(Map.of(call.arguments as Map));
          return null;
        });
    for (final appearance in [Brightness.dark, Brightness.light]) {
      await render(
        tester,
        const CupertinoPageScaffold(
          child: Center(
            child: Ios26Surface(
              radius: 28,
              child: SizedBox(width: 300, height: 54),
            ),
          ),
        ),
        brightness: appearance,
      );
      await tester.pumpAndSettle();
      expect(
        (tester.widget<UiKitView>(find.byType(UiKitView)).creationParams
            as Map)['dark'],
        appearance == Brightness.dark,
      );
    }
    expect(creations, hasLength(2));
    expect(creations[0]['id'], isNot(creations[1]['id']));
    final first =
        const StandardMessageCodec().decodeMessage(
              ByteData.sublistView(creations[0]['params'] as Uint8List),
            )
            as Map;
    final last =
        const StandardMessageCodec().decodeMessage(
              ByteData.sublistView(creations[1]['params'] as Uint8List),
            )
            as Map;
    expect(first['dark'], true);
    expect(last['dark'], false);
  });

  testWidgets('glass tab selection animates from its current position', (
    tester,
  ) async {
    MotionArtwork.instance.supported = true;
    ios26Design.value = true;
    var selected = 0;
    await render(
      tester,
      CupertinoPageScaffold(
        child: Center(
          child: StatefulBuilder(
            builder: (context, update) => BitChordTabBar(
              selectedIndex: selected,
              onSelect: (index) => update(() => selected = index),
            ),
          ),
        ),
      ),
      reduceMotion: false,
    );
    final indicator = find.byKey(const ValueKey('tab-selection-motion'));
    double x() =>
        (tester
                    .widget<Align>(
                      find
                          .descendant(
                            of: indicator,
                            matching: find.byType(Align),
                          )
                          .first,
                    )
                    .alignment
                as Alignment)
            .x;
    expect(x(), -1);
    await tester.tap(find.text('Explore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(x(), greaterThan(-1));
    expect(x(), lessThan(-1 / 3));
    await capture(tester, 'glass-selection-mid-transition');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(x(), closeTo(1, .001));
    expect(selected, 3);
  });

  testWidgets('player keeps glass off controls and animates playback state', (
    tester,
  ) async {
    MotionArtwork.instance.supported = true;
    ios26Design.value = true;
    motionArtworkEnabled.value = true;
    await render(tester, const NowPlayingPage(), reduceMotion: false);
    expect(find.byType(Ios26Surface), findsNothing);
    // Enabling video without attaching a clip must keep a still cover.
    expect(find.byType(UiKitView), findsNothing);
    final artwork = find.byKey(const ValueKey('playback-artwork-scale'));
    double scale() => tester
        .widget<ScaleTransition>(
          find
              .descendant(of: artwork, matching: find.byType(ScaleTransition))
              .first,
        )
        .scale
        .value;
    expect(scale(), 1);
    handler.playbackState.add(
      PlaybackState(
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(), greaterThan(.92));
    expect(scale(), lessThan(1));
    await capture(tester, 'playback-pause-mid-transition');
    await tester.pumpAndSettle();
    expect(scale(), closeTo(.92, .001));
    await capture(tester, 'player-glass-enabled-dark');
    handler.playbackState.add(
      PlaybackState(playing: true, processingState: AudioProcessingState.ready),
    );
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduce Motion settles playback and tab feedback immediately', (
    tester,
  ) async {
    MotionArtwork.instance.supported = true;
    ios26Design.value = true;
    await render(tester, const NowPlayingPage());
    handler.playbackState.add(
      PlaybackState(
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );
    await tester.pump();
    await tester.pump();
    final scale = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('playback-artwork-scale')),
    );
    expect(scale.duration, Duration.zero);
    expect(scale.scale, .92);
    await render(
      tester,
      CupertinoPageScaffold(
        child: Center(
          child: BitChordTabBar(selectedIndex: 0, onSelect: (_) {}),
        ),
      ),
    );
    expect(
      tester
          .widget<AnimatedAlign>(
            find.byKey(const ValueKey('tab-selection-motion')),
          )
          .duration,
      Duration.zero,
    );
  });

  testWidgets('rapid return to a track keeps one artwork Hero during fades', (
    tester,
  ) async {
    await render(tester, const NowPlayingPage(), reduceMotion: false);
    final first = handler.mediaItem.value!;
    handler.mediaItem.add(first.copyWith(id: 'second', title: 'Second track'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    handler.mediaItem.add(first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.byType(Hero), findsOneWidget);
    expect(
      tester.widget<Hero>(find.byType(Hero)).tag,
      'playing-art-${first.id}',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('mini-player skip and root expansion respond to gestures', (
    tester,
  ) async {
    await render(
      tester,
      const CupertinoPageScaffold(child: Center(child: MiniPlayer())),
    );
    await tester.drag(find.byType(MiniPlayer), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(handler.next, 1);
    await tester.tap(find.byType(MiniPlayer));
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mini-player pull follows the finger before release', (
    tester,
  ) async {
    await render(
      tester,
      const CupertinoPageScaffold(child: Center(child: MiniPlayer())),
    );
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(MiniPlayer)),
    );
    await finger.moveBy(const Offset(0, -120));
    await tester.pump();
    await finger.moveBy(const Offset(0, -120));
    await tester.pump();
    final top = tester.getTopLeft(find.byType(NowPlayingPage)).dy;
    expect(top, greaterThan(0));
    expect(top, lessThan(844));
    await finger.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(NowPlayingPage)).dy, closeTo(0, .1));
  });

  testWidgets('inline queue respects autoplay state and track menu opens', (
    tester,
  ) async {
    final oldAutoplay = playNextSongAutomatically.value;
    addTearDown(() => playNextSongAutomatically.value = oldAutoplay);
    await render(tester, const NowPlayingPage());
    await tester.tap(find.byIcon(CupertinoIcons.list_bullet));
    await tester.pumpAndSettle();
    expect(find.text('Continuous Autoplay Active'), findsOneWidget);
    playNextSongAutomatically.value = false;
    await tester.pump();
    expect(find.text('Continuous Autoplay Active'), findsNothing);
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('Play Next'), findsOneWidget);
    expect(find.text('Sleep timer'), findsOneWidget);
    await capture(tester, 'track-menu-dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('player sheet tracks a partial pull and cancels or completes', (
    tester,
  ) async {
    late BuildContext ctx;
    await render(
      tester,
      Builder(
        builder: (context) {
          ctx = context;
          return const CupertinoPageScaffold(child: Text('Library'));
        },
      ),
    );
    final route = PlayerSheetRoute(
      interactive: true,
      builder: (_) => const CupertinoPageScaffold(child: Text('Player')),
    );
    Navigator.of(ctx, rootNavigator: true).push(route);
    await tester.pump();
    route.dragBy(-200, 844);
    await tester.pump();
    expect(route.animation!.value, closeTo(200 / 844, .01));
    route.settle(-500, opening: true);
    await tester.pumpAndSettle();
    expect(route.animation!.value, 1);
    route.dragBy(400, 844);
    route.settle(500);
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Player'), findsNothing);
  });

  for (final name in ['home', 'explore', 'library', 'search']) {
    testWidgets('$name reference layout renders with fixture catalogue', (
      tester,
    ) async {
      userRecentlyPlayed.value = [
        for (var i = 0; i < 6; i++)
          {
            'ytid': 'fixture$i',
            'title': 'Night drive ${i + 1}',
            'artist': 'Musyn Sessions',
          },
      ];
      trendingSongs.value = List.from(userRecentlyPlayed.value);
      final page = switch (name) {
        'home' => HomePage(loadFeed: () async {}),
        'explore' => ExplorePage(
          loadCategories: () async => [
            {
              'title': 'Chill',
              'browseId': 'FEmusic_moods_and_genres_category',
              'params': 'chill',
              'stripeColor': 0xff567f83,
            },
            {
              'title': 'Energy',
              'browseId': 'FEmusic_moods_and_genres_category',
              'params': 'energy',
              'stripeColor': 0xff91644a,
            },
            {
              'title': 'Focus',
              'browseId': 'FEmusic_moods_and_genres_category',
              'params': 'focus',
              'stripeColor': 0xff61744f,
            },
            {
              'title': 'Feel good',
              'browseId': 'FEmusic_moods_and_genres_category',
              'params': 'feelgood',
              'stripeColor': 0xff66517d,
            },
          ],
        ),
        'library' => const LibraryPage(),
        _ => const SearchPage(),
      };
      final index = ['home', 'explore', 'library', 'search'].indexOf(name);
      await render(
        tester,
        Builder(
          builder: (context) => Stack(
            children: [
              MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.only(bottom: 160)),
                child: page,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MiniPlayer(),
                    BitChordTabBar(selectedIndex: index, onSelect: (_) {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await capture(tester, '$name-dark');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  const songs = [
    {
      'ytid': 'first',
      'title': 'First light',
      'artist': 'Musyn Sessions',
      'listeningCount': 2,
    },
    {
      'ytid': 'second',
      'title': 'Night drive',
      'artist': 'Musyn Sessions',
      'listeningCount': 12,
    },
  ];

  testWidgets(
    'search landing and typing have useful states; late suggestions stay hidden',
    (tester) async {
      await tester.runAsync(
        () => Hive.box('user').put('searchHistory', <dynamic>[]),
      );
      final suggestions = Completer<List<String>>();
      await render(
        tester,
        SearchPage(
          loadSongs: (_) async => songs,
          loadArtists: (_) async => [],
          loadPlaylists: (_) async => [],
          loadSuggestions: (_) => suggestions.future,
        ),
      );
      expect(find.text('Find your next favorite'), findsOneWidget);
      expect(find.text('Moods & genres'), findsOneWidget);
      expect(find.text('Charts'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoSearchTextField), 'Night');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Ready to search'), findsOneWidget);
      expect(find.text('No matches found'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      suggestions.complete(['Late irrelevant suggestion']);
      await tester.pumpAndSettle();
      expect(find.text('Late irrelevant suggestion'), findsNothing);
      expect(find.text('First light'), findsWidgets);
      await tester.tap(find.text('Artists').first);
      await tester.pumpAndSettle();
      expect(find.text('No artists in these results'), findsOneWidget);
      await tester.tap(find.text('Show all results'));
      await tester.pumpAndSettle();
      expect(find.text('First light'), findsWidgets);
    },
  );

  testWidgets('failed search retries instead of claiming zero matches', (
    tester,
  ) async {
    var attempts = 0;
    await render(
      tester,
      SearchPage(
        initialQuery: 'Night',
        loadSongs: (_) async {
          if (++attempts == 1) throw StateError('offline');
          return songs;
        },
        loadArtists: (_) async => [],
        loadPlaylists: (_) async => [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search is unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry search'));
    await tester.pumpAndSettle();
    expect(find.text('First light'), findsWidgets);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
    await capture(tester, 'search-results-dark');
  });

  testWidgets('failed playlist retries, empty custom collection stays local', (
    tester,
  ) async {
    var attempts = 0;
    await render(
      tester,
      PlaylistPage(
        playlistId: 'PLtest',
        loadPlaylist: (_) async {
          if (++attempts == 1) throw StateError('offline');
          return {'ytid': 'PLtest', 'title': 'Night sessions', 'list': songs};
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Collection unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry collection'));
    await tester.pumpAndSettle();
    expect(find.text('Night sessions'), findsWidgets);
    expect(find.text('First light'), findsOneWidget);
    await capture(tester, 'playlist-dark');
    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzzz');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();
    expect(find.text('First light'), findsOneWidget);
    var fetched = false;
    await render(
      tester,
      PlaylistPage(
        key: const ValueKey('empty'),
        playlistData: const {
          'ytid': 'local',
          'title': 'My playlist',
          'source': 'user-created',
          'list': <Map>[],
        },
        loadPlaylist: (_) async {
          fetched = true;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(fetched, isFalse);
    expect(find.text('Find tracks to add'), findsOneWidget);
    expect(find.text('Collection unavailable'), findsNothing);
  });

  testWidgets(
    'remote refresh keeps previous songs on failure and retries actual loader',
    (tester) async {
      var calls = 0;
      await render(
        tester,
        PlaylistPage(
          playlistId: 'saavn_chart_test',
          loadPlaylist: (_) async {
            if (++calls == 2) throw StateError('refresh failed');
            return {
              'ytid': 'saavn_chart_test',
              'title': 'Chart',
              'source': 'saavn',
              'list': calls > 2 ? songs.reversed.toList() : songs,
            };
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.arrow_2_circlepath));
      await tester.pumpAndSettle();
      expect(find.text('Could not refresh this collection'), findsOneWidget);
      expect(find.text('First light'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry collection'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('Could not refresh this collection'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await render(
        tester,
        PlaylistPage(
          key: const ValueKey('empty-remote'),
          playlistId: 'PLempty',
          loadPlaylist: (_) async => {
            'ytid': 'PLempty',
            'title': 'Unavailable remote',
            'list': <Map>[],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Collection unavailable'), findsOneWidget);
      expect(find.text('Retry collection'), findsOneWidget);
    },
  );

  testWidgets('artist failures expose retry and can recover', (tester) async {
    var attempts = 0;
    await render(
      tester,
      ArtistPage(
        artistId: 'UCfixture',
        loadArtist: (_) async {
          if (++attempts == 1) throw StateError('offline');
          return {
            'ytid': 'UCfixture',
            'title': 'Musyn Sessions',
            'topSongs': [
              {'song': songs.first},
            ],
            'releases': <Map>[],
            'relatedArtists': <Map>[],
          };
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry artist'), findsOneWidget);
    await tester.tap(find.text('Retry artist'));
    await tester.pumpAndSettle();
    expect(find.text('Musyn Sessions'), findsWidgets);
    expect(find.text('First light'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'artist-dark');
  });

  testWidgets('lyrics keeps a continuous background and compact controls', (
    tester,
  ) async {
    lastFetchedLyrics = 'Musyn Sessions - Midnight in motion';
    lyrics.value =
        '[00:00.00]Midnight in motion\n[00:12.00]A quiet melody\n[00:42.00]In your rhythm\n[01:10.00]Another day begins';
    await render(tester, const NowPlayingPage(), size: const Size(402, 874));
    await tester.tap(find.bySemanticsLabel('Lyrics'));
    await tester.pumpAndSettle();
    expect(find.text('Midnight in motion'), findsWidgets);
    expect(find.byIcon(CupertinoIcons.volume_up), findsNothing);
    expect(find.bySemanticsLabel('Next track'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final line = tester.widget<Text>(find.text('In your rhythm'));
    expect(line.textAlign, TextAlign.center);
    final textStyle = tester.widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.text('In your rhythm'),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    );
    expect(textStyle.style.color, const Color(0xFFFF8FB1));
    await capture(tester, 'lyrics-dark');
    lastFetchedLyrics = null;
    lyrics.value = null;
  });

  testWidgets(
    'chart Play is actionable and duplicate taps do not restart loading',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await render(
        tester,
        ChartsPage(
          loadYoutube: () async => [
            {
              'ytid': 'PLchart',
              'title': 'Weekly music videos',
              'chartGroup': 'videos',
              'chartCountry': 'IN',
            },
          ],
          loadSaavn: () async => [],
          playChart: (_) {
            calls++;
            return pending.future;
          },
        ),
      );
      await tester.pump();
      expect(find.text('Music-video charts'), findsOneWidget);
      expect(
        find.textContaining('song chart is not currently available'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(CupertinoIcons.play_circle_fill));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.play_circle_fill), findsOneWidget);
    },
  );

  testWidgets('charts isolate provider failures and retry real collections', (
    tester,
  ) async {
    jiosaavnEnabled.value = true;
    var attempts = 0;
    await render(
      tester,
      ChartsPage(
        loadYoutube: () async {
          if (++attempts == 1) throw StateError('offline');
          return [
            {
              'ytid': 'PLchart',
              'title': 'Top songs',
              'chartGroup': 'songs',
              'subtitle': 'YouTube Music',
            },
          ];
        },
        loadSaavn: () async => [
          {
            'ytid': 'saavn_chart',
            'title': 'India Top 50',
            'subtitle': 'JioSaavn',
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry charts'), findsOneWidget);
    await tester.tap(find.text('JioSaavn'));
    await tester.pumpAndSettle();
    expect(find.text('India Top 50'), findsOneWidget);
    expect(find.text('Retry charts'), findsNothing);
    await tester.tap(find.text('YouTube Music'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry charts'));
    await tester.pumpAndSettle();
    expect(find.text('Top songs'), findsOneWidget);
    await capture(tester, 'charts-dark');
  });

  testWidgets('stalled catalogue leaves loading with a recovery action', (
    tester,
  ) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    await render(tester, ExplorePage(loadCategories: () => pending.future));
    expect(find.text('Loading catalogue'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Catalogue unavailable'), findsOneWidget);
    expect(find.text('Retry catalogue'), findsOneWidget);
    pending.complete([]);
    await tester.pump();
    expect(find.text('Catalogue unavailable'), findsOneWidget);
  });

  testWidgets('downloads can cancel individual transfers and clear filters', (
    tester,
  ) async {
    userOfflineSongs.value = List.from(songs);
    final token = DownloadCancellation();
    final id = downloadActivity.begin(songs.first, token);
    downloadActivity.start(id);
    downloadActivity.progress(id, 512000, 1024000);
    await render(tester, const DownloadsPage());
    expect(find.textContaining('50%'), findsOneWidget);
    await capture(tester, 'downloads-dark');
    await tester.tap(find.byKey(ValueKey('cancel-download-$id')));
    await tester.pump();
    expect(token.isCancelled, isTrue);
    expect(find.textContaining('Cancelling…'), findsOneWidget);
    downloadActivity.finish(id, false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Cancelled'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('download-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear finished'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching downloads'), findsOneWidget);
    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();
    expect(find.text('First light'), findsOneWidget);
  });

  testWidgets('most played playback follows ranked visible order', (
    tester,
  ) async {
    userRecentlyPlayed.value = List.from(songs);
    await render(tester, const UserSongsPage(page: 'mostPlayed'));
    await tester.ensureVisible(find.text('Night drive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night drive'));
    await tester.pump();
    expect(
      (handler.playedPlaylist!['list'] as List).map((song) => song['ytid']),
      ['second', 'first'],
    );
    expect(handler.playedIndex, 0);
  });

  testWidgets(
    'new playlist validates without dismissing and creates in chosen folder',
    (tester) async {
      userPlaylistFolders.value = [
        {'id': 'folder', 'name': 'Night', 'playlists': <Map>[]},
      ];
      await render(
        tester,
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () =>
                    showCreatePlaylistDialog(context, folderId: 'folder'),
                child: const Text('New'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a playlist name.'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), 'Night sessions');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(
        (userPlaylistFolders.value.single['playlists'] as List).single['title'],
        'Night sessions',
      );
      expect(find.text('New Playlist'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'search catalogue links navigate to real mood and chart destinations',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/search',
        routes: [
          GoRoute(
            path: '/search',
            builder: (_, _) => const SearchPage(),
            routes: [
              GoRoute(
                path: 'charts',
                builder: (_, _) => ChartsPage(
                  loadYoutube: () async => [
                    {'ytid': 'PLchart', 'title': 'Chart collection'},
                  ],
                  loadSaavn: () async => [],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/explore',
            builder: (_, _) => const CupertinoPageScaffold(
              child: Text('Mood catalogue destination'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await render(tester, CupertinoApp.router(routerConfig: router));
      await tester.ensureVisible(find.text('Charts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Charts'));
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);
      expect(find.text('Chart collection'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Moods & genres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moods & genres'));
      await tester.pumpAndSettle();
      expect(find.text('Mood catalogue destination'), findsOneWidget);
    },
  );

  testWidgets('home feed failure retains discovery and refresh recovery', (
    tester,
  ) async {
    await render(
      tester,
      HomePage(loadFeed: () async => throw StateError('offline')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Refresh music'), findsOneWidget);
    expect(find.text('Moods & genres'), findsOneWidget);
    expect(find.text('Charts'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'home-error-dark');
  });

  testWidgets(
    'library artwork menu pins collections and deletes only after confirmation',
    (tester) async {
      userCustomPlaylists.value = [
        {
          'ytid': 'custom',
          'title': 'Night sessions',
          'source': 'user-created',
          'list': songs,
        },
      ];
      await render(tester, const LibraryPage());
      await tester.ensureVisible(find.text('Night sessions'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Night sessions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin to Library'));
      await tester.pumpAndSettle();
      expect(pinnedPlaylistIds.value, ['custom']);
      await tester.ensureVisible(find.text('Night sessions').last);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Night sessions').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Playlist'));
      await tester.pumpAndSettle();
      expect(userCustomPlaylists.value, isNotEmpty);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(userCustomPlaylists.value, isEmpty);
      expect(pinnedPlaylistIds.value, isEmpty);
    },
  );

  testWidgets(
    'deleted folder and unknown user collection expose library recovery',
    (tester) async {
      await render(
        tester,
        const PlaylistFolderPage(folderId: 'missing', folderName: 'Missing'),
      );
      expect(find.text('This folder is no longer available'), findsOneWidget);
      expect(find.text('Open library'), findsOneWidget);
      await render(tester, const UserSongsPage(page: 'unknown'));
      expect(find.text('Open library'), findsOneWidget);
    },
  );

  testWidgets(
    'streaming quality choices persist without changing source preference',
    (tester) async {
      final source = preferredSource.value;
      await render(tester, const SettingsPage());
      await tester.tap(find.text('Playback'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('YouTube quality'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YouTube quality'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Data saver'));
      await tester.pumpAndSettle();
      expect(audioQualitySetting.value, 'low');
      expect(Hive.box('settings').get('audioQuality'), 'low');
      expect(preferredSource.value, source);
      audioQualitySetting.value = 'high';
    },
  );

  testWidgets('default provider selection is an explicit choice', (
    tester,
  ) async {
    preferredSource.value = 'auto';
    await render(tester, const SettingsPage());
    await tester.tap(find.text('Playback'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Default source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default source'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoActionSheetAction>(
            find.ancestor(
              of: find.text('Automatic').last,
              matching: find.byType(CupertinoActionSheetAction),
            ),
          )
          .isDefaultAction,
      isTrue,
    );
    await tester.tap(find.text('YouTube Music').last);
    await tester.pumpAndSettle();
    expect(preferredSource.value, 'youtube');
    preferredSource.value = 'auto';
  });

  for (final light in [false, true]) {
    testWidgets(
      'download sheet small large-text ${light ? 'light' : 'dark'} keeps quality and download reachable',
      (tester) async {
        jiosaavnEnabled.value = false;
        String? provider;
        String? quality;
        await render(
          tester,
          Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () => showDownloadPicker(context, songs.first, (
                    source,
                    bitrate,
                  ) {
                    provider = source;
                    quality = bitrate;
                  }),
                  child: const Text('Choose download'),
                ),
              ),
            ),
          ),
          size: const Size(320, 568),
          scale: 1.8,
          brightness: light ? Brightness.light : Brightness.dark,
        );
        await tester.tap(find.text('Choose download'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'download-sheet-small-${light ? 'light' : 'dark'}',
        );
        await tester.ensureVisible(find.text('128 kbps'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('128 kbps'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Download Track'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Download Track'));
        await tester.pumpAndSettle();
        expect(provider, 'youtube');
        expect(quality, '128');
        jiosaavnEnabled.value = true;
      },
    );
  }

  testWidgets(
    'source sheet small large-text failure offers a reachable retry',
    (tester) async {
      jiosaavnEnabled.value = true;
      var calls = 0;
      await render(
        tester,
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () => showAudioSourcePicker(
                  context,
                  handler.mediaItem.value!,
                  switchSource: (source) async {
                    calls++;
                    return calls == 1 ? null : source;
                  },
                ),
                child: const Text('Choose source'),
              ),
            ),
          ),
        ),
        size: const Size(320, 568),
        scale: 1.8,
      );
      await tester.tap(find.text('Choose source'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('JioSaavn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JioSaavn'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not switch source.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'source-sheet-small-dark');
      await tester.tap(find.text('JioSaavn'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('JioSaavn'), findsNothing);
    },
  );

  for (final light in [false, true]) {
    for (final name in [
      'settings',
      'downloads',
      'playlist',
      'library',
      'explore',
      'home',
      'search',
      'charts',
    ]) {
      testWidgets(
        '$name small phone large text ${light ? 'light' : 'dark'} scrolls without overflow',
        (tester) async {
          userOfflineSongs.value = List.from(songs);
          userCustomPlaylists.value = [
            {
              'ytid': 'custom',
              'title': 'Night sessions with a longer title',
              'source': 'user-created',
              'list': songs,
            },
          ];
          userPlaylistFolders.value = [
            {'id': 'folder', 'name': 'Night sessions', 'playlists': <Map>[]},
          ];
          final page = switch (name) {
            'home' => HomePage(
              loadFeed: () async {
                trendingSongs.value = List.from(songs);
              },
            ),
            'search' => SearchPage(
              initialQuery: 'Night',
              loadSongs: (_) async => songs,
              loadArtists: (_) async => [],
              loadPlaylists: (_) async => [],
            ),
            'charts' => ChartsPage(
              loadYoutube: () async => [
                {
                  'ytid': 'PLchart',
                  'title': 'Top songs chart',
                  'subtitle': 'YouTube Music',
                },
              ],
              loadSaavn: () async => [],
            ),
            'settings' => const SettingsPage(),
            'downloads' => const DownloadsPage(),
            'playlist' => PlaylistPage(
              playlistData: userCustomPlaylists.value.first,
            ),
            'library' => const LibraryPage(),
            _ => ExplorePage(
              loadCategories: () async => [
                {
                  'title': 'Feel good music',
                  'browseId': 'moods',
                  'params': 'good',
                },
              ],
            ),
          };
          await render(
            tester,
            page,
            size: const Size(320, 568),
            scale: 1.8,
            brightness: light ? Brightness.light : Brightness.dark,
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            '$name-small-large-text-${light ? 'light' : 'dark'}',
          );
          for (var i = 0; i < 6; i++) {
            final vertical = find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            );
            if (vertical.evaluate().isNotEmpty)
              await tester.drag(vertical.first, const Offset(0, -350));
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  testWidgets(
    'playlist download cancellation remains separate on small large-text layout',
    (tester) async {
      const id = 'batch';
      final service = offlinePlaylistService;
      service.activeDownloads.add(id);
      service.activeTitles[id] = 'Night sessions playlist download';
      service.getProgressNotifier(id).value = DownloadProgress(
        total: 10,
        completed: 2,
        failed: 1,
      );
      service.activeDownloadIds.value = [id];
      await render(
        tester,
        const DownloadsPage(),
        size: const Size(320, 568),
        scale: 1.8,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('2 of 10 saved · 1 failed'), findsOneWidget);
      await tester.tap(find.text('Cancel playlist'));
      await tester.pump();
      expect(
        service.getProgressNotifier(id).value.cancellation.isCancelled,
        isTrue,
      );
      expect(find.text('Cancelling…'), findsOneWidget);
      service.activeDownloads.remove(id);
      service.activeTitles.remove(id);
      service.activeDownloadIds.value = [];
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      service.cleanupProgressNotifier(id);
      expect(tester.takeException(), isNull);
    },
  );

  for (final small in [false, true]) {
    for (final destination in const {
      'Downloads': 'Download source',
      'Appearance': 'Theme',
      'YouTube Music': 'Connect YouTube Music',
      'Storage & diagnostics': 'Repair YouTube playback',
    }.entries) {
      testWidgets(
        'Settings ${destination.key} has working navigation ${small ? 'large text' : 'standard'}',
        (tester) async {
          await render(
            tester,
            const SettingsPage(),
            size: small ? const Size(320, 568) : const Size(390, 844),
            scale: small ? 1.8 : 1,
          );
          await tester.scrollUntilVisible(
            find.text(destination.key),
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(destination.key));
          await tester.pumpAndSettle();
          expect(find.text(destination.value), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'settings-${destination.key.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '-')}-${small ? 'large-text' : 'detail'}',
          );
          await tester.tap(find.byType(CupertinoNavigationBarBackButton).first);
          await tester.pumpAndSettle();
          expect(find.text('Settings'), findsWidgets);
        },
      );
    }
  }
  for (final small in [false, true]) {
    testWidgets(
      'connected account exposes sync failure and persists preference ${small ? 'large text' : 'standard'}',
      (tester) async {
        final auth = YouTubeAuthService();
        final sync = YouTubeMusicSyncService();
        auth.isSignedIn.value = true;
        sync.pendingLikes.value = 2;
        sync.syncError.value =
            'Favorites are saved on this iPhone and waiting to sync.';
        ytAutoSyncLikes.value = true;
        try {
          await render(
            tester,
            const SettingsPage(),
            size: small ? const Size(320, 568) : const Size(390, 844),
            scale: small ? 1.8 : 1,
            brightness: small ? Brightness.light : Brightness.dark,
          );
          await tester.tap(find.text('YouTube Music'));
          await tester.pumpAndSettle();
          expect(find.text('2 pending'), findsOneWidget);
          expect(
            find.text(
              'Favorites are saved on this iPhone and waiting to sync.',
            ),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Sync favorites'));
          await tester.pumpAndSettle();
          await capture(
            tester,
            'settings-account-${small ? 'large-text' : 'connected'}',
          );
          await tester.tap(find.byType(CupertinoSwitch).first);
          await tester.pumpAndSettle();
          expect(ytAutoSyncLikes.value, isFalse);
          expect(Hive.box('settings').get('ytAutoSyncLikes'), isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          auth.isSignedIn.value = false;
          sync.pendingLikes.value = 0;
          sync.syncError.value = null;
          ytAutoSyncLikes.value = true;
        }
      },
    );
  }
  testWidgets(
    'splash keeps branding stationary when slow-start status appears',
    (tester) async {
      final pending = Completer<void>();
      await render(
        tester,
        MusynBootstrap(
          minimumDisplay: Duration.zero,
          initialize: (report) {
            report('Starting the player');
            return pending.future;
          },
          readyBuilder: (_) => const CupertinoApp(home: Text('Library ready')),
        ),
      );
      final logo = find.image(
        const AssetImage('assets/branding/musyn-icon.png'),
      );
      final before = tester.getCenter(logo);
      expect(find.text('Starting the player'), findsNothing);
      await capture(tester, 'splash-dark');
      await tester.pump(const Duration(seconds: 4));
      expect(tester.getCenter(logo), before);
      expect(find.text('Starting the player'), findsOneWidget);
      await capture(tester, 'splash-slow-dark');
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Library ready'), findsOneWidget);
    },
  );

  for (final light in [false, true]) {
    testWidgets(
      'settings full layout ${light ? 'light' : 'dark'} renders appearance and quality sections',
      (tester) async {
        await render(
          tester,
          const SettingsPage(),
          brightness: light ? Brightness.light : Brightness.dark,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, 'settings-${light ? 'light' : 'dark'}');
        await tester.tap(find.text('Playback'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('YouTube quality'));
        await tester.pumpAndSettle();
        await capture(tester, 'quality-settings-${light ? 'light' : 'dark'}');
      },
    );
  }

  testWidgets('folder collection rows render with real collection actions', (
    tester,
  ) async {
    userPlaylistFolders.value = [
      {
        'id': 'folder',
        'name': 'Night sessions',
        'playlists': [
          {
            'ytid': 'custom',
            'title': 'Night drive collection',
            'source': 'user-created',
            'list': songs,
          },
        ],
      },
    ];
    await render(
      tester,
      const PlaylistFolderPage(
        folderId: 'folder',
        folderName: 'Night sessions',
      ),
    );
    expect(find.text('Night drive collection'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'folder-dark');
  });

  for (final small in [false, true]) {
    testWidgets(
      'Musyn walkthrough ${small ? 'large text' : 'standard'} is complete and skippable',
      (tester) async {
        var completed = 0;
        await render(
          tester,
          OnboardingPage(
            onComplete: () async {
              completed++;
            },
          ),
          size: small ? const Size(320, 568) : const Size(390, 844),
          scale: small ? 1.8 : 1,
        );
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          small ? 'walkthrough-small' : 'walkthrough-welcome',
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('One player. Your sources.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          small ? 'walkthrough-sources-small' : 'walkthrough-sources',
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Bring your own source.'), findsOneWidget);
        await capture(
          tester,
          small ? 'walkthrough-provider-small' : 'walkthrough-provider',
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await capture(
          tester,
          small ? 'walkthrough-ready-small' : 'walkthrough-ready',
        );
        await tester.tap(find.text('Start listening'));
        await tester.pump();
        expect(completed, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final label in ['Privacy', 'Terms of use']) {
    testWidgets(
      'public Settings $label has a real page and working back navigation',
      (tester) async {
        await render(
          tester,
          const SettingsPage(),
          size: const Size(320, 568),
          scale: 1.6,
        );
        await tester.scrollUntilVisible(
          find.text(label),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(LegalPage), findsOneWidget);
        expect(find.text('Updated 20 October 2026'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          label == 'Privacy' ? 'privacy-dark' : 'terms-dark',
        );
        await tester.tap(find.byType(CupertinoNavigationBarBackButton).first);
        await tester.pumpAndSettle();
        expect(find.byType(LegalPage), findsNothing);
      },
    );
  }
  testWidgets(
    'provider setup saves a supplied key and removal restores keyless use',
    (tester) async {
      await ProviderAccess.instance.remove();
      jiosaavnEnabled.value = false;
      await render(tester, const ProviderAccessPage());
      expect(find.text('No key is configured.'), findsOneWidget);
      await capture(tester, 'provider-setup-dark');
      await tester.enterText(find.byType(CupertinoTextField), 'fixture!');
      await tester.tap(find.text('Save key'));
      await tester.pumpAndSettle();
      expect(ProviderAccess.instance.configured, isTrue);
      expect(jiosaavnAvailable, isTrue);
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller!
            .text,
        isEmpty,
      );
      await tester.ensureVisible(find.text('Remove key'));
      await tester.tap(find.text('Remove key'));
      await tester.pumpAndSettle();
      expect(ProviderAccess.instance.configured, isFalse);
      expect(preferredSource.value, 'auto');
      expect(downloadSource.value, 'best');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'diagnostic preview redacts private URLs and upload cancellation sends nothing',
    (tester) async {
      logger.clearLogs();
      logger.log(
        'Fixture playback title=Midnight URL=https://audio.example/private?token=fake',
      );
      await render(tester, const LogsPage());
      expect(find.textContaining('audio.example'), findsNothing);
      await capture(tester, 'support-dark');
      await tester.tap(find.text('Upload to dpaste'));
      await tester.pumpAndSettle();
      expect(find.text('Upload these logs?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.text('Upload to dpaste'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in [
    (name: 'player-dark', size: const Size(390, 844), light: false, scale: 1.0),
    (name: 'player-light', size: const Size(390, 844), light: true, scale: 1.0),
    (
      name: 'player-small',
      size: const Size(320, 568),
      light: false,
      scale: 1.0,
    ),
    (
      name: 'player-large-text',
      size: const Size(390, 844),
      light: false,
      scale: 1.8,
    ),
    (
      name: 'player-landscape-large-text',
      size: const Size(568, 320),
      light: false,
      scale: 1.8,
    ),
    (
      name: 'player-landscape',
      size: const Size(844, 390),
      light: false,
      scale: 1.0,
    ),
  ]) {
    testWidgets('${entry.name} has no layout exceptions', (tester) async {
      if (entry.name == 'player-landscape') {
        lastFetchedLyrics = 'Musyn Sessions - Midnight in motion';
        lyrics.value =
            '[00:00.00]Midnight in motion\n[00:12.00]A quiet melody\n[00:42.00]In your rhythm\n[01:10.00]Another day begins';
      }
      await render(
        tester,
        const NowPlayingPage(),
        size: entry.size,
        brightness: entry.light ? Brightness.light : Brightness.dark,
        scale: entry.scale,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, entry.name);
    });
  }
}
