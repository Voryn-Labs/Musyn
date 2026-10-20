import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/automatic_artwork_resolver.dart';
import 'package:musyn/services/automatic_artwork_store.dart';
import 'package:musyn/services/io_service.dart';
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
  bool _listening = false;

  Future<void> initialize() async {
    try {
      supported = await channel.invokeMethod<bool>('supported') ?? false;
    } on MissingPluginException {
      supported = false;
    } on PlatformException {
      supported = false;
    }
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
