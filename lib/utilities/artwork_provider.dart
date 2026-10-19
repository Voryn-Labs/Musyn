import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Upgrades streaming thumbnail URLs to square, high-resolution formats.
String upgradeArtworkUrl(String url, {int targetSize = 400}) {
  if (url.isEmpty || url == 'null') return url;

  var upgraded = url;
  if (upgraded.contains('googleusercontent.com') ||
      upgraded.contains('ggpht.com')) {
    if (upgraded.contains('=')) {
      upgraded = upgraded
          .replaceAll(
            RegExp(r'=w\d+(?:-h\d+)?(?:-[a-zA-Z0-9]+)*'),
            '=w$targetSize-h$targetSize-c-l90-rj',
          )
          .replaceAll(RegExp(r'=s\d+(?:-[a-zA-Z0-9]+)*'), '=s$targetSize-c');
    } else {
      upgraded = '$upgraded=w$targetSize-h$targetSize-c-l90-rj';
    }
  }

  if (upgraded.contains('saavncdn.com')) {
    upgraded = upgraded
        .replaceAll('50x50.jpg', '500x500.jpg')
        .replaceAll('150x150.jpg', '500x500.jpg')
        .replaceAll('500x500.jpg', '500x500.jpg')
        .replaceAll('1500x1500.jpg', '500x500.jpg');
  }

  // hqdefault is universally available at 480px. mqdefault was only 320px
  // wide and was being cropped and enlarged on both the player and lock screen.
  if (upgraded.contains('ytimg.com/') || upgraded.contains('youtube.com/vi/')) {
    upgraded = upgraded.replaceAllMapped(
      RegExp(r'/(default|mqdefault)\.(jpg|webp|jpeg)'),
      (match) => '/hqdefault.${match[2]}',
    );
  }

  return upgraded;
}

class ArtworkProvider {
  ArtworkProvider._();

  static const int _maxEntries = 80;
  static final Map<String, ImageProvider> _cache = {};

  static ImageProvider get(String artwork) {
    if (artwork.isEmpty) throw ArgumentError('artwork must not be empty');

    final cached = _cache.remove(artwork);
    if (cached != null) {
      _cache[artwork] = cached;
      return cached;
    }

    late ImageProvider provider;
    try {
      if (artwork.startsWith('http')) {
        final upgraded = upgradeArtworkUrl(artwork);
        provider = CachedNetworkImageProvider(upgraded);
      } else if (artwork.startsWith('data:image')) {
        final commaIdx = artwork.indexOf(',');
        if (commaIdx == -1) throw Exception('invalid base64 image');
        final bytes = base64Decode(artwork.substring(commaIdx + 1));
        provider = MemoryImage(bytes);
      } else if (!kIsWeb &&
          (artwork.startsWith('file://') || artwork.startsWith('/'))) {
        final path = artwork.startsWith('file:')
            ? Uri.parse(artwork).toFilePath()
            : artwork;
        provider = FileImage(File(path));
      } else {
        provider = AssetImage(artwork);
      }
    } catch (_) {
      provider = const AssetImage('assets/icons/musyn_icon.png');
    }

    _cache[artwork] = provider;
    _trimIfNeeded();
    return provider;
  }

  static void _trimIfNeeded() {
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  static void clearCache() => _cache.clear();
}
