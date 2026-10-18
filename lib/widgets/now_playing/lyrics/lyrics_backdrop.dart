import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:musified/utilities/artwork_provider.dart';
import 'package:musified/utilities/mediaitem.dart' show resolveMediaArtworkUrl;
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';

/// Full-screen blurred artwork atmosphere behind lyrics.
class LyricsBackdrop extends StatelessWidget {
  const LyricsBackdrop({
    super.key,
    required this.metadata,
    required this.theme,
  });

  final MediaItem metadata;
  final LyricsTheme theme;

  String? _artUrl() =>
      metadata.artUri?.toString() ??
      resolveMediaArtworkUrl(
        metadata.extras ?? {},
        ytid: metadata.extras?['ytid']?.toString() ?? metadata.id,
        targetSize: 800,
      );

  @override
  Widget build(BuildContext context) {
    final artwork = _artUrl();
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: 1.15,
          child: artwork == null || artwork.isEmpty
              ? ColoredBox(color: theme.canvas)
              : Image(
                  image: ArtworkProvider.get(artwork),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(color: theme.canvas),
                ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
          child: const ColoredBox(color: Color(0x00000000)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.isDark
                  ? [
                      const Color(0xCC000000),
                      const Color(0xE60A0A0E),
                      const Color(0xF00A0A0E),
                      const Color(0xFF000000),
                    ]
                  : [
                      const Color(0xDDF2F2F7),
                      const Color(0xF0F7F7FA),
                      const Color(0xF8F7F7FA),
                      const Color(0xFFF2F2F7),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}
