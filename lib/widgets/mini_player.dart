import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/constants/player_layout.dart';
import 'package:musified/models/full_player_state.dart';
import 'package:musified/screens/now_playing_page.dart';
import 'package:musified/services/audio/audio_runtime.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/mediaitem.dart' show upgradeArtworkUrl;

/// BitChord-inspired iOS floating mini player with horizontal swipe-to-skip
/// and upward drag to expand.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  static const double playerHeight = miniPlayerHeight;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  // Swipe-to-skip physics controller
  late final AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  double _dragOffset = 0;
  static const double _swipeThreshold = 64;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _swipeAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _openNowPlaying() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, _) => const NowPlayingPage(),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta ?? 0.0;
      // Dampen drag after threshold
      if (_dragOffset.abs() > _swipeThreshold) {
        final excess = _dragOffset.abs() - _swipeThreshold;
        final sign = _dragOffset >= 0 ? 1 : -1;
        _dragOffset = sign * (_swipeThreshold + excess * 0.35);
      }
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset < -_swipeThreshold) {
      // Swiped left -> Next track
      HapticFeedback.mediumImpact();
      audioHandler.skipToNext();
    } else if (_dragOffset > _swipeThreshold) {
      // Swiped right -> Previous track
      HapticFeedback.mediumImpact();
      audioHandler.skipToPrevious();
    }

    // Spring back to center
    _swipeAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0,
    ).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );
    _swipeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isAudioHandlerInitialized) return const SizedBox.shrink();

    return StreamBuilder<FullPlayerState>(
      stream: audioHandler.fullPlayerStateStream,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data;
        final metadata = state?.mediaItem;
        if (metadata == null || state == null) {
          return const SizedBox.shrink();
        }

        final isDark = isAppDarkMode(context);
        final bg = isDark
            ? const Color(0xE6161618)
            : const Color(0xF2FFFFFF);
        final border = isDark
            ? const Color(0x33FFFFFF)
            : const Color(0x1F000000);
        final titleColor = isDark
            ? CupertinoColors.white
            : CupertinoColors.black;
        final artistColor = isDark
            ? MusifiedStyle.darkSecondary
            : CupertinoColors.systemGrey;

        final metadataDuration = metadata.duration;
        final totalDuration =
            (metadataDuration != null && metadataDuration > Duration.zero)
            ? metadataDuration
            : (state.position.duration > Duration.zero
                  ? state.position.duration
                  : Duration.zero);
        final progress = totalDuration.inMilliseconds == 0
            ? 0.0
            : (state.position.position.inMilliseconds /
                      totalDuration.inMilliseconds)
                  .clamp(0.0, 1.0);

        final ytid = metadata.extras?['ytid']?.toString() ?? metadata.id;
        final rawImage =
            metadata.artUri?.toString() ??
            metadata.extras?['lowResImage']?.toString() ??
            metadata.extras?['image']?.toString() ??
            'https://i.ytimg.com/vi/$ytid/hqdefault.jpg';
        final imageUrl = upgradeArtworkUrl(rawImage, targetSize: 120);

        final isPlaying = state.playbackState.playing;
        final isLoading =
            state.playbackState.processingState ==
                AudioProcessingState.loading ||
            state.playbackState.processingState ==
                AudioProcessingState.buffering;
        final hasNext = audioHandler.hasNext;

        final currentSwipeOffset = _swipeController.isAnimating
            ? _swipeAnimation.value
            : _dragOffset;

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTapDown: (_) => _pressController.forward(),
                onTapUp: (_) => _pressController.reverse(),
                onTapCancel: () => _pressController.reverse(),
                onTap: _openNowPlaying,
                onVerticalDragEnd: (details) {
                  // Drag up opens now playing
                  if ((details.primaryVelocity ?? 0) < -150) {
                    _openNowPlaying();
                  }
                },
                onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      height: MiniPlayer.playerHeight,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
                        border: Border.all(color: border, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Thin progress line along the bottom of the pill
                          Positioned(
                            bottom: 0,
                            left: 18,
                            right: 18,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: Container(
                                height: 2,
                                color: isDark
                                    ? const Color(0x22FFFFFF)
                                    : const Color(0x11000000),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    color: MusifiedStyle.appleRed,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Main content with horizontal swipe translation
                          Transform.translate(
                            offset: Offset(currentSwipeOffset, 0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  // Artwork
                                  Hero(
                                    tag: 'now_playing_art_$ytid',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 120,
                                          memCacheHeight: 120,
                                          errorWidget: (_, __, ___) => ColoredBox(
                                            color: musifiedSecondarySurface(isDark),
                                            child: const Icon(
                                              CupertinoIcons.music_note,
                                              size: 20,
                                              color: CupertinoColors.systemGrey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Track info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          metadata.title,
                                          style: TextStyle(
                                            fontFamily: MusifiedStyle.uiFont,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.2,
                                            color: titleColor,
                                            decoration: TextDecoration.none,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          metadata.artist ?? '',
                                          style: TextStyle(
                                            fontFamily: MusifiedStyle.uiFont,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: artistColor,
                                            decoration: TextDecoration.none,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Transport controls
                                  if (isLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CupertinoActivityIndicator(
                                        radius: 11,
                                      ),
                                    )
                                  else
                                    CupertinoButton(
                                      padding: const EdgeInsets.all(8),
                                      minimumSize: const Size(40, 40),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        if (isPlaying) {
                                          audioHandler.pause();
                                        } else {
                                          audioHandler.play();
                                        }
                                      },
                                      child: Icon(
                                        isPlaying
                                            ? CupertinoIcons.pause_fill
                                            : CupertinoIcons.play_fill,
                                        color: titleColor,
                                        size: 24,
                                      ),
                                    ),
                                  if (hasNext)
                                    CupertinoButton(
                                      padding: const EdgeInsets.all(8),
                                      minimumSize: const Size(40, 40),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        audioHandler.skipToNext();
                                      },
                                      child: Icon(
                                        CupertinoIcons.forward_fill,
                                        color: titleColor.withValues(alpha: 0.8),
                                        size: 22,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
