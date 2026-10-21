import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:musyn/services/bounded_jobs.dart';
import 'package:musyn/utilities/artwork_provider.dart' show artworkCandidates;

/// Shares a square, locally cached cover with Now Playing and the app. Artwork
/// fetching never blocks audio resolution or installation.
class PlayerArtworkCache {
  static final _pending = BoundedJobs<String, Uri>(capacity: 40);
  static bool _clearing = false;
  static final _resolved = <String, Uri>{};
  static const _channel = MethodChannel('com.vorynlabs.musyn/artwork');

  static Uri? cached(Uri remote) => _resolved[remote.toString()];

  static Future<Uri?> prepare(Uri uri) {
    if (_clearing) return Future.value();
    final key = uri.toString();
    return _pending.run(key, () async {
      final local = await _prepare(uri);
      if (local != null) {
        _resolved[key] = local;
        if (_resolved.length > 40) _resolved.remove(_resolved.keys.first);
      }
      return local;
    });
  }

  static Future<void> clear() async {
    _clearing = true;
    try {
      await _pending.drain();
      _resolved.clear();
    } finally {
      _clearing = false;
    }
  }

  static Future<Uri?> _prepare(Uri uri) async {
    if (!{'https', 'http', 'file'}.contains(uri.scheme)) return null;
    try {
      final cache = DefaultCacheManager();
      final key = '$uri#musyn-square-v4';
      final cached = await cache.getFileFromCache(key);
      if (cached != null && await cached.file.exists()) return cached.file.uri;
      final videoThumbnail =
          uri.host.endsWith('ytimg.com') &&
          (uri.path.contains('/vi/') || uri.path.contains('/vi_webp/'));
      Uint8List? bytes;
      final candidates = uri.scheme == 'file'
          ? [uri.toString()]
          : artworkCandidates(uri.toString(), targetSize: 1024);
      for (final candidate in candidates) {
        try {
          final file = uri.scheme == 'file'
              ? File.fromUri(uri)
              : await cache
                    .getSingleFile(candidate)
                    .timeout(const Duration(seconds: 5));
          bytes = await squareCover(
            await file.readAsBytes(),
            videoThumbnail: videoThumbnail,
            minimumWidth: candidate.contains('/maxresdefault.') ? 480 : 0,
          );
          if (bytes != null) break;
        } catch (_) {
          /* Try the known thumbnail fallback. */
        }
      }
      if (bytes == null) return null;
      final file = await cache.putFile(key, bytes, fileExtension: 'png');
      return file.uri;
    } catch (_) {
      return null; // Preserve the remote cover if offline or decoding fails.
    }
  }

  /// Removes video-thumbnail letterboxing before making a square cover.
  static Future<Uint8List?> squareCover(
    Uint8List bytes, {
    bool videoThumbnail = false,
    int minimumWidth = 0,
  }) async {
    // Flutter's raster surface can be suspended while lock-screen audio keeps
    // running. Native ImageIO/Core Graphics works without an active Flutter frame.
    if (Platform.isIOS) {
      return _channel.invokeMethod<Uint8List>('squareCover', {
        'bytes': bytes,
        'videoThumbnail': videoThumbnail,
        'minimumWidth': minimumWidth,
      });
    }
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1440,
      allowUpscaling: false,
    );
    final ui.FrameInfo frame;
    try {
      frame = await codec.getNextFrame();
    } finally {
      codec.dispose();
    }
    final image = frame.image;
    try {
      if (image.width < minimumWidth) return null;
      final contentHeight = videoThumbnail
          ? math.min(image.height.toDouble(), image.width * 9 / 16)
          : image.height.toDouble();
      final side = math.min(image.width.toDouble(), contentHeight);
      final source = ui.Rect.fromLTWH(
        (image.width - side) / 2,
        (image.height - side) / 2,
        side,
        side,
      );
      final size = math.min(side, 1024).round();
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image,
        source,
        ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final square = await picture.toImage(size, size);
      picture.dispose();
      try {
        final png = await square.toByteData(format: ui.ImageByteFormat.png);
        return png?.buffer.asUint8List();
      } finally {
        square.dispose();
      }
    } finally {
      image.dispose();
    }
  }
}
