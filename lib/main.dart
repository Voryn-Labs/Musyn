import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musyn/extensions/l10n.dart';
import 'package:musyn/localization/app_localizations.dart';
import 'package:musyn/screens/onboarding_page.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/audio/carplay.dart';
import 'package:musyn/services/audio/remote_favorites.dart';
import 'package:musyn/services/audio_service.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/deferred_links.dart';
import 'package:musyn/services/io_service.dart';
import 'package:musyn/services/home_widget_bridge.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/services/motion_artwork.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/services/playlist_sharing.dart';
import 'package:musyn/services/playlists_manager.dart';
import 'package:musyn/services/provider_access.dart';
import 'package:musyn/services/router_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/source_resolver.dart';
import 'package:musyn/services/smart_library.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/services/ytdlp_client_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/language_utils.dart';
import 'package:musyn/utilities/playlist_utils.dart';
import 'package:musyn/widgets/musyn_bootstrap.dart';
import 'package:path_provider/path_provider.dart';

export 'package:musyn/services/audio/audio_runtime.dart';
export 'package:musyn/services/logger_service.dart' show logger, Logger;

// Re-exported from logger_service for files that import main.dart.
final appLinks = AppLinks();
final _incomingPlaylists = DeferredLinks(_importPlaylistLink);

class MusynApp extends StatefulWidget {
  const MusynApp({super.key});

  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    context.findAncestorStateOfType<_MusynAppState>()?.changeSettings(
      newThemeMode: newThemeMode,
      newLocale: newLocale,
      newAccentColor: newAccentColor,
      systemColorStatus: useSystemColor,
    );
  }

  @override
  _MusynAppState createState() => _MusynAppState();
}

typedef Musyn = MusynApp;

class _MusynAppState extends State<MusynApp> with WidgetsBindingObserver {
  void changeSettings({
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? systemColorStatus,
  }) {
    setState(() {
      if (newThemeMode != null) {
        themeMode = newThemeMode;
        themeModeSetting.value = newThemeMode.index;
        brightness = getBrightnessFromThemeMode(newThemeMode);
      }
      if (newLocale != null) {
        languageSetting = newLocale;
      }
      if (newAccentColor != null) {
        if (systemColorStatus != null &&
            useSystemColor.value != systemColorStatus) {
          useSystemColor.value = systemColorStatus;
          addOrUpdateData<bool>(
            'settings',
            'useSystemColor',
            systemColorStatus,
          );
        }
        primaryColorSetting = newAccentColor;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    logger.log('Musyn started');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _incomingPlaylists.attach();
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    offlineMode.addListener(_onOfflineModeChanged);
    themeModeSetting.addListener(_onThemeChanged);
    usePureBlackColor.addListener(_onThemeChanged);
    musynSkinSetting.addListener(_onThemeChanged);

    try {
      LicenseRegistry.addLicense(() async* {
        final license = await rootBundle.loadString(
          'assets/licenses/paytone.txt',
        );
        yield LicenseEntryWithLineBreaks(['paytoneOne'], license);
      });
    } catch (e, stackTrace) {
      logger.log(
        'License Registration Error',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    MotionArtwork.instance.refreshSelection();
    if (!isAudioHandlerInitialized) return;
    unawaited(audioHandler.resyncAfterForeground());
  }

  @override
  void didChangePlatformBrightness() {
    if (themeMode != ThemeMode.system) return;
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (brightness == next) return;
    setState(() {
      brightness = next;
    });
  }

  @override
  void dispose() {
    _incomingPlaylists.detach();
    WidgetsBinding.instance.removeObserver(this);
    offlineMode.removeListener(_onOfflineModeChanged);
    themeModeSetting.removeListener(_onThemeChanged);
    usePureBlackColor.removeListener(_onThemeChanged);
    musynSkinSetting.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onOfflineModeChanged() {
    setState(() {});
  }

  void _onThemeChanged() {
    syncThemeFromSettings();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final overlayBrightness = getBrightnessFromThemeMode(themeMode);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: const Color(0x00000000),
        systemNavigationBarContrastEnforced: true,
        statusBarBrightness: overlayBrightness,
        statusBarIconBrightness: overlayBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarIconBrightness: overlayBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: CupertinoApp.router(
        title: 'Musyn',
        debugShowCheckedModeBanner: false,
        theme: buildCupertinoTheme(brightness: overlayBrightness),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: appSupportedLocales,
        locale: languageSetting,
        routerConfig: NavigationManager.router,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger.resetForNewSession();
  configureImageMemoryBudget();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    final canvas = usePureBlackColor.value
        ? MusynStyle.oledBlack
        : MusynStyle.elevated;
    return ColoredBox(
      color: canvas,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.systemRed,
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                'Musyn Notice',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                kDebugMode
                    ? '${details.exception}\n\n${details.stack?.toString().split('\n').take(12).join('\n') ?? ''}'
                    : 'This view could not be displayed. Reopen Musyn to try again. Your saved music stays on this device.',
                style: const TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.log(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  runApp(
    MusynBootstrap(
      initialize: (report) async {
        await initialisation(onProgress: report);
        if (!isAudioHandlerInitialized)
          throw StateError('Audio initialization failed');
        unawaited(cleanupOldCacheEntries());
      },
      readyBuilder: (_) => FirstRunGate(readyBuilder: (_) => const MusynApp()),
    ),
  );
}

Future<void> initialisation({ValueChanged<String>? onProgress}) async {
  final elapsed = Stopwatch()..start();
  void report(String stage) {
    logger.log('Startup stage=$stage elapsedMs=${elapsed.elapsedMilliseconds}');
    onProgress?.call(stage);
  }

  // Phase 1: Hive + settings (never let this kill the app)
  try {
    report('Opening your library');
    await Hive.initFlutter().timeout(const Duration(seconds: 10));

    await Future.wait([
      Hive.openBox('settings'),
      Hive.openBox('user'),
      Hive.openBox('userNoBackup'),
      Hive.openBox('cache'),
      Hive.openBox('youtube_auth'),
    ]).timeout(const Duration(seconds: 15));
    // Restore persisted settings into ValueNotifiers + theme globals
    await ProviderAccess.instance.initialize();
    await MotionArtwork.instance.initialize();
    reloadSettingsFromStorage();
    syncThemeFromSettings();
    await YtdlpClientSyncService.instance.ensureLoaded();
    reloadSongLibraryStateFromStorage();
    await SmartLibrary.instance.initialize();
    reloadPlaylistsStateFromStorage();
    OfflinePlaylistService().reloadOfflinePlaylistsFromStorage();
    // Restore YouTube Music session if previously signed in
    YouTubeAuthService().restoreSession();
    unawaited(YouTubeMusicSyncService().initialize());
  } catch (e, stackTrace) {
    logger.log('Hive Initialization Error', error: e, stackTrace: stackTrace);
  }

  // Phase 2: directories (must succeed for offline)
  try {
    applicationDirPath = (await getApplicationDocumentsDirectory()).path;
    await FilePaths.ensureDirectoriesExist();
  } catch (e, stackTrace) {
    logger.log('Directory init error', error: e, stackTrace: stackTrace);
    // Fallback to temp dir so app still launches
    try {
      applicationDirPath = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      applicationDirPath = '/tmp';
    }
  }

  // Phase 3: audio + saavn (isolated so router always initializes)
  try {
    report('Preparing music sources');
    await SourceResolver().init().timeout(const Duration(seconds: 5));
  } catch (e, stackTrace) {
    logger.log('SourceResolver init error', error: e, stackTrace: stackTrace);
  }

  try {
    // Bounded so a slow/stuck native AudioService setup can never stall the
    // whole app: if it doesn't finish in time we fall through to the plain
    // MusynAudioHandler() below (no system media integration, but songs
    // still play), instead of leaving `audioHandlerInstance` null forever.
    report('Starting the player');
    audioHandlerInstance = await AudioService.init(
      builder: MusynAudioHandler.new,
      config: const AudioServiceConfig(
        artDownscaleWidth: 1024,
        artDownscaleHeight: 1024,
        preloadArtwork: true,
        fastForwardInterval: Duration(seconds: 15),
        rewindInterval: Duration(seconds: 15),
      ),
    ).timeout(const Duration(seconds: 9));
  } catch (e, stackTrace) {
    logger.log('AudioService init error', error: e, stackTrace: stackTrace);
    try {
      // ignore: deprecated_member_use
      await AudioService.stop();
    } catch (_) {}
    try {
      audioHandlerInstance = MusynAudioHandler();
      logger.log('Created fallback MusynAudioHandler without AudioService');
    } catch (e2, st2) {
      logger.log('Fallback handler also failed', error: e2, stackTrace: st2);
    }
  }
  if (audioHandlerInstance == null) {
    try {
      audioHandlerInstance = MusynAudioHandler();
    } catch (e, st) {
      logger.log('Last-resort handler failed', error: e, stackTrace: st);
    }
  }
  audioHandlerReady.value = audioHandlerInstance != null;
  if (audioHandlerInstance != null) {
    HomeWidgetBridge.start(audioHandlerInstance!);
  }
  // Warm a single likely selection during the splash, without autoplay or a
  // native player item. A tap shares the pending lookup if it arrives first.
  final recent = userRecentlyPlayed.value.whereType<Map>().firstOrNull;
  if (audioHandlerInstance != null && recent != null) {
    unawaited(audioHandlerInstance!.primeSong(recent));
  }
  if (defaultTargetPlatform == TargetPlatform.iOS &&
      audioHandlerInstance != null) {
    remoteFavorites.start(audioHandlerInstance!);
    carPlay.start(audioHandlerInstance!);
  }

  report('Opening Musyn');
  // Phase 4: router - MUST always run
  try {
    NavigationManager.instance;
  } catch (e, stackTrace) {
    logger.log('Router init error', error: e, stackTrace: stackTrace);
  }

  // Phase 5: deep links
  try {
    final initialUri = await appLinks.getInitialLink().timeout(
      const Duration(seconds: 3),
    );
    if (initialUri != null) {
      unawaited(handleIncomingLink(initialUri));
    }
    appLinks.uriLinkStream.listen(
      (uri) => unawaited(handleIncomingLink(uri)),
      onError: (err) {
        logger.log('URI link error:', error: err);
      },
    );
  } on PlatformException {
    logger.log('Failed to get initial uri');
  } catch (e, stackTrace) {
    logger.log('AppLinks listen error', error: e, stackTrace: stackTrace);
  }
  logger.log('Startup complete elapsedMs=${elapsed.elapsedMilliseconds}');
}

Future<void> handleIncomingLink(Uri? uri) async {
  if (uri == null ||
      uri.scheme != 'musyn' ||
      uri.host != 'playlist' ||
      uri.toString().length > 66000)
    return;
  _incomingPlaylists.receive(uri);
}

Future<void> _importPlaylistLink(Uri uri) async {
  if (uri.scheme != 'musyn' || uri.host != 'playlist') return;

  if (uri.pathSegments.length < 2 || uri.pathSegments[0] != 'custom') return;

  try {
    final encodedPlaylist = uri.pathSegments[1];
    if (encodedPlaylist.length > 65536) {
      logger.log('Rejected oversized playlist deep link');
      _showPlaylistError();
      return;
    }
    final playlist = await PlaylistSharingService.decodeAndExpandPlaylist(
      encodedPlaylist,
    );

    if (playlist == null) {
      _showPlaylistError();
      return;
    }

    // Ensure the incoming playlist has a unique id so it can be removed later
    if (playlist['ytid'] == null || playlist['ytid'].toString().isEmpty) {
      playlist['ytid'] = PlaylistUtils.generateCustomPlaylistId();
    }

    // Check for duplicate by title and song ytids
    final incomingYtids = (playlist['list'] as List<dynamic>)
        .map((s) => s['ytid'].toString())
        .toList();

    final isDuplicate = PlaylistUtils.playlistExists(
      playlist,
      incomingYtids,
      userCustomPlaylists.value,
    );

    final navContext =
        NavigationManager.router.routerDelegate.navigatorKey.currentContext;

    if (isDuplicate) {
      if (navContext != null)
        showToast(navContext, navContext.l10n.playlistAlreadyExists);
    } else {
      userCustomPlaylists.value = [...userCustomPlaylists.value, playlist];
      await addOrUpdateData<List>(
        'user',
        'customPlaylists',
        userCustomPlaylists.value,
      );
      if (navContext != null)
        showToast(navContext, '${navContext.l10n.addedSuccess}!');
    }
  } catch (e, stackTrace) {
    logger.log(
      'Failed to handle playlist deep link',
      error: e,
      stackTrace: stackTrace,
    );
    _showPlaylistError();
  }
}

void _showPlaylistError() {
  final navContext =
      NavigationManager.router.routerDelegate.navigatorKey.currentContext;
  if (navContext == null) return;
  showToast(navContext, navContext.l10n.failedToLoadPlaylist);
}
