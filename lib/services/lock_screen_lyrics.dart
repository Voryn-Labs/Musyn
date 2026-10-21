import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:musyn/widgets/now_playing/lyrics/lrc_parser.dart';

final lockScreenLyricsEnabled = ValueNotifier<bool>(false);
final lockScreenArtworkLyricsEnabled = ValueNotifier<bool>(false);

/// Sends timed lines once per selection. Native playback drives their clock,
/// including when Flutter's UI is suspended. Plain lyrics never get fake timing.
class LockScreenLyrics {
  LockScreenLyrics({
    required this.load,
    this.channel = const MethodChannel('com.vorynlabs.musyn/motion'),
  });
  final Future<String?> Function(MediaItem) load;
  final MethodChannel channel;
  String? _selection;
  MediaItem? _item;
  int _epoch = 0;
  Future<void> pending = Future.value();

  void select(MediaItem? item, {required bool enabled, bool artwork = false}) {
    _item = item;
    final key = (enabled || artwork) && item != null
        ? '${item.id}|${item.artist}|${item.title}|$enabled|$artwork'
        : null;
    if (key == _selection) return;
    _selection = key;
    final epoch = ++_epoch;
    pending = _publish(item, enabled, artwork, epoch);
  }

  void refresh() {
    _selection = 'refresh';
    select(
      _item,
      enabled: lockScreenLyricsEnabled.value,
      artwork: lockScreenArtworkLyricsEnabled.value,
    );
  }

  Future<void> _publish(
    MediaItem? item,
    bool enabled,
    bool artwork,
    int epoch,
  ) async {
    try {
      await channel.invokeMethod<void>('lyrics', {
        'id': item?.id,
        'enabled': false,
        'lines': <Map<String, dynamic>>[],
      });
      if ((!enabled && !artwork) || item == null || epoch != _epoch) return;
      final raw = await load(item);
      if (epoch != _epoch) return;
      final lines = parseLrcLyrics(raw ?? '');
      await channel.invokeMethod<void>('lyrics', {
        'id': item.id,
        'enabled': true,
        'artist': enabled,
        'artwork': artwork,
        'lines': lines
            .take(1500)
            .map(
              (line) => {
                'at': line.time.inMilliseconds.toDouble(),
                'text': line.text,
              },
            )
            .toList(),
      });
    } on MissingPluginException {
      /* Earlier platforms keep standard metadata. */
    } on PlatformException {
      /* Lyrics must never interrupt audio. */
    } catch (_) {
      /* A provider miss keeps the real artist row. */
    }
  }

  void dispose() {
    ++_epoch;
  }
}
