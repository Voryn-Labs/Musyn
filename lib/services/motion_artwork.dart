import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/io_service.dart';
import 'package:musyn/utilities/app_utils.dart';

final ios26Design = ValueNotifier<bool>(false);
final motionArtworkEnabled = ValueNotifier<bool>(false);

class MotionArtwork extends ChangeNotifier {
  static final instance = MotionArtwork();
  static const channel = MethodChannel('com.vorynlabs.musyn/motion');
  bool supported = false;
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
    motionArtworkEnabled.value =
        supported &&
        Hive.box('settings').get('motionArtwork', defaultValue: false);
    notifyListeners();
  }

  String? fileFor(String id) {
    if (!Hive.isBoxOpen('userNoBackup')) return null;
    final file = Hive.box('userNoBackup').get('motion:$id');
    if (file is! String) return null;
    final path = '$applicationDirPath/motion/$file';
    return File(path).existsSync() ? path : null;
  }

  Future<void> importFor(MediaItem item) async {
    if (!supported) throw StateError('Video artwork requires iOS 26 or later.');
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov'],
    );
    if (picked == null || picked.path == null) return;
    final file = File(picked.path!);
    if (await file.length() > 20 * 1024 * 1024)
      throw StateError('Choose a clip smaller than 20 MB.');
    final valid = await channel.invokeMethod<bool>('validate', file.path);
    if (valid != true)
      throw StateError(
        'Use a silent square or 3:4 portrait video, 0.5–30 seconds long.',
      );
    final id = item.extras?['ytid']?.toString() ?? item.id;
    final directory = Directory('$applicationDirPath/motion');
    await directory.create(recursive: true);
    final name =
        '${sanitizeStorageSongId(id)}-${DateTime.now().microsecondsSinceEpoch}.mp4';
    await file.copy('${directory.path}/$name');
    await Hive.box('userNoBackup').put('motion:$id', name);
    motionArtworkEnabled.value = true;
    await Hive.box('settings').put('motionArtwork', true);
    notifyListeners();
  }

  Future<void> removeFor(String id) async {
    final path = fileFor(id);
    await Hive.box('userNoBackup').delete('motion:$id');
    notifyListeners();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
