import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/automatic_artwork_resolver.dart';
import 'package:musyn/services/automatic_artwork_store.dart';
import 'package:musyn/services/io_service.dart';
import 'package:musyn/services/lock_screen_lyrics.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:path_provider/path_provider.dart';

final ios26Design = ValueNotifier<bool>(false);
final motionArtworkEnabled = ValueNotifier<bool>(false);

class MotionArtwork extends ChangeNotifier {
  static final instance = MotionArtwork();
  static const channel = MethodChannel('com.vorynlabs.musyn/motion');
  bool supported = false;
  AutomaticArtworkStore? _automatic;
  MediaItem? _selection;
  String? _diagnosticTrack;
  Timer? _diagnosticTimer;
  bool _listening = false;

  Future<void> initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'prepared') {
        try {
          await _automatic?.prune();
        } catch (_) {}
        try {
          final info = await channel.invokeMapMethod<String, dynamic>(
            'diagnostics',
          );
          logger.log(
            'Lock screen artwork prepared',
            data: info?.cast<String, Object?>(),
          );
        } catch (_) {}
      }
    });
    try {
      supported = await channel.invokeMethod<bool>('supported') ?? false;
    } on MissingPluginException {
      supported = false;
    } on PlatformException {
      supported = false;
    }
    lockScreenLyricsEnabled.value = Hive.box(
      'settings',
    ).get('lockScreenLyrics', defaultValue: false);
    ios26Design.value =
        supported &&
        Hive.box('settings').get('ios26Design', defaultValue: false);
    // Existing explicit opt-outs survive. No setting means automatic on iOS 26.
    motionArtworkEnabled.value =
        supported &&
        Hive.box('settings').get('motionArtwork', defaultValue: true);
    if (supported) {
      try {
        final root = await getApplicationCacheDirectory();
        _automatic?.removeListener(notifyListeners);
        _automatic?.dispose();
        _automatic = AutomaticArtworkStore(
          directory: Directory('${root.path}/musyn-motion'),
          cache: Hive.box('cache'),
          report: (state) => logger.log('Automatic artwork: $state'),
          resolverFactory: () => AutomaticArtworkResolver(
            country:
                PlatformDispatcher.instance.locale.countryCode?.toLowerCase() ??
                'us',
          ),
          validate: (path) async =>
              await channel.invokeMethod<bool>('validate', path) ?? false,
          retainedPaths: () async =>
              (await channel.invokeListMethod<String>('retainedPaths') ??
                      <String>[])
                  .toSet(),
          canFetch: () async =>
              await channel.invokeMethod<bool>('canFetch') ?? false,
        )..addListener(notifyListeners);
      } catch (_) {
        // Artwork is optional: cache/path-provider failures cannot block startup.
      }
    }
    if (!_listening) {
      motionArtworkEnabled.addListener(refreshSelection);
      offlineMode.addListener(refreshSelection);
      _listening = true;
    }
    notifyListeners();
  }

  void select(MediaItem? item) {
    _selection = item;
    if (item?.id != _diagnosticTrack) {
      _diagnosticTrack = item?.id;
      _diagnosticTimer?.cancel();
      _diagnosticTimer = Timer(const Duration(seconds: 8), () async {
        try {
          final info = await channel.invokeMapMethod<String, dynamic>(
            'diagnostics',
          );
          logger.log(
            'Lock screen snapshot',
            data: info?.cast<String, Object?>(),
          );
        } catch (_) {}
      });
    }
    _automatic?.select(
      item,
      enabled: supported && motionArtworkEnabled.value && !offlineMode.value,
    );
  }

  void refreshSelection() {
    _automatic?.select(null, enabled: false);
    select(_selection);
  }

  String? fileFor(String id) {
    // Keep existing user overrides, but no manual import is required or prompted.
    if (Hive.isBoxOpen('userNoBackup')) {
      final file = Hive.box('userNoBackup').get('motion:$id');
      if (file is String && !file.contains('/') && !file.contains('..')) {
        final path = '$applicationDirPath/motion/$file';
        if (File(path).existsSync()) return path;
      }
    }
    return _automatic?.fileFor(id);
  }

  Future<void> clearCache() async => _automatic?.clear(
    beforeDelete: () => channel.invokeMethod<void>('clear'),
  );
}
