import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:musified/services/audio/audio_runtime.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/utilities/mediaitem.dart' show upgradeArtworkUrl;
import 'package:musified/widgets/flip_card.dart';
import 'package:musified/widgets/now_playing/bottom_actions_row.dart';
import 'package:musified/widgets/now_playing/now_playing_artwork.dart';
import 'package:musified/widgets/now_playing/now_playing_controls.dart';
import 'package:musified/widgets/queue_list_view.dart';

/// Apple Music & BitChord-inspired Now Playing screen with ambient artwork aura.
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final _lyricsController = FlipCardController();

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final isDark = isAppDarkMode(context);
    final bg = musifiedCanvas(isDark);
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : (screenWidth < 400 ? 40.0 : 44.0);
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) {
            Navigator.pop(context);
          }
        },
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            final metadata = snapshot.data;
            if (metadata == null) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final ytid = metadata.extras?['ytid']?.toString() ?? metadata.id;
            final rawImage =
                metadata.artUri?.toString() ??
                metadata.extras?['lowResImage']?.toString() ??
                metadata.extras?['image']?.toString() ??
                'https://i.ytimg.com/vi/$ytid/hqdefault.jpg';
            final ambientUrl = upgradeArtworkUrl(rawImage, targetSize: 300);

            return Stack(
              children: [
                // 1. Ambient blurred artwork backdrop (Apple Music style)
                Positioned.fill(
                  child: OverflowBox(
                    maxWidth: size.width * 1.5,
                    maxHeight: size.height * 1.5,
                    child: Opacity(
                      opacity: isDark ? 0.35 : 0.22,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                        child: CachedNetworkImage(
                          imageUrl: ambientUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Translucent gradient scrim to ensure 100% legibility
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                const Color(0x66000000),
                                const Color(0x99000000),
                                const Color(0xF2000000),
                              ]
                            : [
                                const Color(0x55FFFFFF),
                                const Color(0x88FFFFFF),
                                const Color(0xF5FFFFFF),
                              ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Foreground content
                SafeArea(
                  child: Column(
                    children: [
                      _Grabber(isDark: isDark),
                      Expanded(
                        child: isLargeScreen
                            ? _DesktopLayout(
                                metadata: metadata,
                                size: size,
                                adjustedIconSize: baseIconSize,
                                adjustedMiniIconSize: miniIconSize,
                                lyricsController: _lyricsController,
                              )
                            : _MobileLayout(
                                metadata: metadata,
                                size: size,
                                adjustedIconSize: baseIconSize,
                                adjustedMiniIconSize: miniIconSize,
                                isLargeScreen: isLargeScreen,
                                lyricsController: _lyricsController,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Center(
        child: Container(
          width: 38,
          height: 5,
          decoration: BoxDecoration(
            color: isDark ? const Color(0x55FFFFFF) : const Color(0x33000000),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.lyricsController,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final FlipCardController lyricsController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: NowPlayingArtwork(
                      size: size,
                      metadata: metadata,
                      lyricsController: lyricsController,
                    ),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: true,
                  lyricsController: lyricsController,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const Expanded(child: QueueWidget()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.lyricsController,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final FlipCardController lyricsController;

  @override
  Widget build(BuildContext context) {
    if (size.width > size.height) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
                lyricsController: lyricsController,
              ),
            ),
          ),
          if (!isLive)
            Expanded(
              flex: 5,
              child: NowPlayingControls(
                size: size,
                audioId: metadata.extras?['ytid'],
                adjustedIconSize: adjustedIconSize * 1.15,
                adjustedMiniIconSize: adjustedMiniIconSize * 1.15,
                metadata: metadata,
              ),
            ),
          BottomActionsRow(
            metadata: metadata,
            iconSize: 24,
            isLargeScreen: isLargeScreen,
            lyricsController: lyricsController,
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
                lyricsController: lyricsController,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                if (!isLive)
                  Expanded(
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                  lyricsController: lyricsController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
