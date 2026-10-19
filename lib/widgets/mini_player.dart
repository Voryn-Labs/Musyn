import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:musyn/constants/player_layout.dart';
import 'package:musyn/models/full_player_state.dart';
import 'package:musyn/models/position_data.dart';
import 'package:musyn/screens/now_playing_page.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/widgets/player_sheet_route.dart';
import 'package:musyn/widgets/song_artwork.dart';

/// Compact iOS player dock with horizontal swipe-to-skip
/// and upward drag to expand.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  static const double playerHeight = miniPlayerHeight;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  // Swipe-to-skip physics controller
  late final AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  double _dragOffset = 0;
  static const double _swipeThreshold = 72;
  OverlayEntry? _pullPreview;
  late final AnimationController _pullController = AnimationController(
    vsync: this,
  );
  String _navigationBase = '/home';

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

    _swipeController = AnimationController.unbounded(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _swipeAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pullPreview?.remove();
    _pullController.dispose();
    _pressController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _openNowPlaying() {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    final route = PlayerSheetRoute(
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      builder: (_) =>
          NowPlayingPage(navigationBase: NavigationPaths.basePathFor(context)),
    );
    Navigator.of(context, rootNavigator: true).push(route);
  }

  void _startPull(DragStartDetails details) {
    FocusManager.instance.primaryFocus?.unfocus();
    _navigationBase = NavigationPaths.basePathFor(context);
    _pullPreview?.remove();
    _pullController
      ..stop()
      ..value = 0;
    // Navigator.push cancels active pointers. Preview in the overlay until
    // release so the original mini-player keeps owning this drag.
    _pullPreview = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _pullController,
            builder: (context, child) => Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: CupertinoColors.black.withValues(
                      alpha: .4 * _pullController.value,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    0,
                    (1 - _pullController.value) *
                        MediaQuery.sizeOf(context).height,
                  ),
                  child: child,
                ),
              ],
            ),
            child: NowPlayingPage(navigationBase: _navigationBase),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_pullPreview!);
  }

  void _updatePull(DragUpdateDetails details) {
    _pullController.value =
        (_pullController.value -
                details.delta.dy / MediaQuery.sizeOf(context).height)
            .clamp(0.0, 1.0);
  }

  void _finishPull(double velocity, {bool cancelled = false}) {
    if (_pullPreview == null) return;
    final progress = _pullController.value;
    final commit =
        !cancelled && (velocity < -350 || (velocity < 350 && progress > .15));
    if (commit) {
      _pullPreview?.remove();
      _pullPreview = null;
      Navigator.of(context, rootNavigator: true).push(
        PlayerSheetRoute(
          initialProgress: progress,
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => NowPlayingPage(navigationBase: _navigationBase),
        ),
      );
    } else {
      _pullController
          .animateTo(
            0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            _pullPreview?.remove();
            _pullPreview = null;
          });
    }
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
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset < -_swipeThreshold || velocity < -600) {
      // Swiped left -> Next track
      HapticFeedback.mediumImpact();
      audioHandler.skipToNext();
    } else if (_dragOffset > _swipeThreshold || velocity > 600) {
      // Swiped right -> Previous track
      HapticFeedback.mediumImpact();
      audioHandler.skipToPrevious();
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dragOffset = 0);
      return;
    }
    _swipeAnimation = _swipeController;
    _swipeController.value = _dragOffset;
    _swipeController
        .animateWith(
          SpringSimulation(
            SpringDescription.withDampingRatio(
              mass: 1,
              stiffness: 320,
              ratio: .8,
            ),
            _dragOffset,
            0,
            velocity,
          ),
        )
        .then((_) {
          if (mounted) setState(() => _dragOffset = 0);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (!isAudioHandlerInitialized) return const SizedBox.shrink();

    return StreamBuilder<FullPlayerState>(
      initialData: FullPlayerState(
        mediaItem: audioHandler.mediaItem.valueOrNull,
        playbackState: audioHandler.playbackState.value,
        queue: audioHandler.queue.value,
        position: PositionData(
          Duration.zero,
          Duration.zero,
          audioHandler.mediaItem.valueOrNull?.duration ?? Duration.zero,
        ),
      ),
      stream: audioHandler.fullPlayerStateStream,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data;
        final metadata = state?.mediaItem;
        if (metadata == null || state == null) {
          return const SizedBox.shrink();
        }

        final isDark = isAppDarkMode(context);
        final bg = musynCanvas(isDark);
        final titleColor = isDark
            ? CupertinoColors.white
            : CupertinoColors.black;
        final artistColor = isDark
            ? MusynStyle.darkSecondary
            : CupertinoColors.systemGrey;

        final isPlaying = state.playbackState.playing;
        final isLoading =
            state.playbackState.processingState ==
                AudioProcessingState.loading ||
            state.playbackState.processingState ==
                AudioProcessingState.buffering;
        final hasNext = audioHandler.hasNext;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _swipeController]),
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                dragStartBehavior: DragStartBehavior.down,
                onTapDown: (_) => _pressController.forward(),
                onTapUp: (_) => _pressController.reverse(),
                onTapCancel: () => _pressController.reverse(),
                onTap: _openNowPlaying,
                onVerticalDragStart: _startPull,
                onVerticalDragUpdate: _updatePull,
                onVerticalDragCancel: () => _finishPull(0, cancelled: true),
                onVerticalDragEnd: (details) =>
                    _finishPull(details.primaryVelocity ?? 0),
                onHorizontalDragStart: (_) {
                  _swipeController.stop();
                  _dragOffset = 0;
                },
                onHorizontalDragCancel: () {
                  _swipeController.stop();
                  setState(() => _dragOffset = 0);
                },
                onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      height: MiniPlayer.playerHeight,
                      decoration: BoxDecoration(color: bg),
                      child: Stack(
                        children: [
                          // Main content with horizontal swipe translation
                          Transform.translate(
                            offset: Offset(
                              _swipeController.isAnimating
                                  ? _swipeAnimation.value
                                  : _dragOffset,
                              0,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  // Artwork
                                  Hero(
                                    flightShuttleBuilder:
                                        SongArtworkWidget.flightShuttle,
                                    tag: 'playing-art-${metadata.id}',
                                    child: SongArtworkWidget(
                                      metadata: metadata,
                                      size: 40,
                                      borderRadius: 7,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Track info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          metadata.title,
                                          style: TextStyle(
                                            fontFamily: MusynStyle.uiFont,
                                            fontSize: 14,
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
                                            fontFamily: MusynStyle.uiFont,
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
                                      minimumSize: const Size(44, 44),
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
                                      minimumSize: const Size(44, 44),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        audioHandler.skipToNext();
                                      },
                                      child: Icon(
                                        CupertinoIcons.forward_fill,
                                        color: titleColor.withValues(
                                          alpha: 0.8,
                                        ),
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
