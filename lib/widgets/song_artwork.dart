import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:musyn/utilities/mediaitem.dart'
    show resolveMediaArtworkUrl, upgradeArtworkUrl;
import 'package:musyn/widgets/no_artwork_cube.dart';

class SongArtworkWidget extends StatelessWidget {
  const SongArtworkWidget({
    super.key,
    required this.size,
    required this.metadata,
    this.borderRadius = 10.0,
    this.errorWidgetIconSize = 20.0,
  });
  static Widget flightShuttle(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) => FittedBox(fit: BoxFit.cover, child: (to.widget as Hero).child);

  final double size;
  final MediaItem metadata;
  final double borderRadius;
  final double errorWidgetIconSize;

  Map<String, dynamic> _songFromMetadata() {
    final ytid = metadata.extras?['ytid']?.toString() ?? metadata.id;
    return {
      'ytid': ytid,
      'catalogImage': metadata.extras?['catalogImage'],
      'highResImage': metadata.extras?['highResImage'],
      'image': metadata.extras?['image'],
      'lowResImage': metadata.extras?['lowResImage'],
      'resolvedSource': metadata.extras?['resolvedSource'],
      'catalogOrigin': metadata.extras?['catalogOrigin'],
    };
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheDimension = (size * devicePixelRatio).round().clamp(64, 800);
    final ytid = metadata.extras?['ytid']?.toString() ?? metadata.id;

    final resolvedUrl = resolveMediaArtworkUrl(
      _songFromMetadata(),
      ytid: ytid,
      targetSize: cacheDimension,
    );
    final rawArtUri = metadata.artUri?.toString();
    final isValidUri =
        rawArtUri != null && rawArtUri.isNotEmpty && rawArtUri != 'null';
    final imageUrl = upgradeArtworkUrl(
      resolvedUrl ?? (isValidUri ? rawArtUri : ''),
      targetSize: cacheDimension,
    );
    final networkArtwork = imageUrl.isEmpty || imageUrl.startsWith('file:')
        ? NullArtworkWidget(iconSize: errorWidgetIconSize, size: size)
        : CachedNetworkImage(
            key: ValueKey('${metadata.id}:$imageUrl'),
            width: size,
            height: size,
            imageUrl: imageUrl,
            memCacheWidth: cacheDimension,
            fadeInDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 300),
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                NullArtworkWidget(iconSize: errorWidgetIconSize, size: size),
            errorWidget: (_, __, ___) =>
                NullArtworkWidget(iconSize: errorWidgetIconSize, size: size),
          );

    return metadata.artUri?.scheme == 'file'
        ? SizedBox(
            width: size,
            height: size,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.file(
                key: ValueKey('${metadata.id}:${metadata.artUri}'),
                File(
                  metadata.artUri?.toFilePath() ??
                      metadata.extras?['artworkPath']?.toString() ??
                      metadata.extras?['artWorkPath']?.toString() ??
                      '',
                ),
                fit: BoxFit.cover,
                cacheWidth: cacheDimension,
                errorBuilder: (_, __, ___) => networkArtwork,
              ),
            ),
          )
        : SizedBox(
            width: size,
            height: size,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: networkArtwork,
            ),
          );
  }
}
