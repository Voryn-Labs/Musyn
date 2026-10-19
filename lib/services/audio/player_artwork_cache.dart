import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shares a square, locally cached cover with Now Playing and the app. Artwork
/// fetching never blocks audio resolution or installation.
class PlayerArtworkCache {
  static final _pending = <String, Future<Uri?>>{};
  static final _resolved = <String, Uri>{};

  static Uri? cached(Uri remote) => _resolved[remote.toString()];

  static Future<Uri?> prepare(Uri uri) {
    final key = uri.toString();
    final existing = _pending[key];
    if (existing != null) return existing;
    final future = _prepare(uri).then((local) {
      if (local != null) {
        _resolved[key] = local;
        if (_resolved.length > 40) _resolved.remove(_resolved.keys.first);
      }
      return local;
    });
    _pending[key] = future;
    if (_pending.length > 40) _pending.remove(_pending.keys.first);
    return future.whenComplete(() {
      if (identical(_pending[key], future)) _pending.remove(key);
    });
  }

  static Future<Uri?> _prepare(Uri uri) async {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    try {
      final cache = DefaultCacheManager();
      final key = '$uri#musyn-square-v1';
      final cached = await cache.getFileFromCache(key);
      if (cached != null && await cached.file.exists()) return cached.file.uri;
      final original = await cache
          .getSingleFile(uri.toString())
          .timeout(const Duration(seconds: 8));
      final videoThumbnail =
          uri.host.endsWith('ytimg.com') &&
          (uri.path.contains('/vi/') || uri.path.contains('/vi_webp/'));
      final bytes = await squareCover(
        await original.readAsBytes(),
        videoThumbnail: videoThumbnail,
      );
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
  }) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 800,
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
      final size = math.min(side, 800).round();
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
