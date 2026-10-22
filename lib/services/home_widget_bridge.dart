import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeWidgetBridge {
  HomeWidgetBridge._();

  static const _channel = MethodChannel('com.vorynlabs.musyn/widgets');
  static StreamSubscription<MediaItem?>? _subscription;

  static void start(AudioHandler handler) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    _subscription?.cancel();
    _subscription = handler.mediaItem.distinct().listen((item) {
      if (item == null) return;
      unawaited(_channel.invokeMethod<void>('update', {
        'id': item.id,
        'title': item.title,
        'artist': item.artist ?? 'Musyn',
        'album': item.album ?? '',
        'artUri': item.artUri?.toString() ?? '',
      }).catchError((_) {}));
    });
  }
}
