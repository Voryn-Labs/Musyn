import 'package:flutter/cupertino.dart';
import 'package:musyn/utilities/artwork_provider.dart';

/// A catalogue sleeve can be downloaded, embedded, or remote.
class CatalogueArtwork extends StatelessWidget {
  const CatalogueArtwork({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.errorWidget,
  });
  final String imageUrl;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const Icon(CupertinoIcons.music_note);
    return Image(
      image: ResizeImage.resizeIfNeeded(
        memCacheWidth,
        null,
        ArtworkProvider.get(imageUrl),
      ),
      fit: fit,
      errorBuilder: (context, error, stack) =>
          errorWidget?.call(context, imageUrl, error) ??
          const Icon(CupertinoIcons.music_note),
    );
  }
}
