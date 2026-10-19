import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/ytdlp_client_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musyn-settings-');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'reload keeps new-install defaults and respects explicit false settings',
    () async {
      final settings = await Hive.openBox('settings');
      reloadSettingsFromStorage();
      expect(playNextSongAutomatically.value, isTrue);
      expect(showAudioQualityBadge.value, isTrue);
      await settings.putAll({
        'playNextSongAutomatically': false,
        'showAudioQualityBadge': false,
      });
      reloadSettingsFromStorage();
      expect(playNextSongAutomatically.value, isFalse);
      expect(showAudioQualityBadge.value, isFalse);
    },
  );

  test('early client load can retry once settings are open', () async {
    final service = YtdlpClientSyncService.instance;
    await service.ensureLoaded();
    final settings = await Hive.openBox('settings');
    final config = builtinVisionOsConfig().toJson()
      ..['clientVersion'] = 'restored-test';
    await settings.put('youtubeVisionOsClient', jsonEncode(config));
    await service.ensureLoaded();
    expect(service.activeConfig.clientVersion, 'restored-test');
  });
}
