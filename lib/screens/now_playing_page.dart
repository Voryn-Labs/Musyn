import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/async_loader.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/mediaitem.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/download_picker_sheet.dart';
import 'package:musyn/widgets/now_playing/source_picker_sheet.dart';
import 'package:musyn/widgets/now_playing/synced_lyrics_view.dart';
import 'package:musyn/widgets/playback_icon_button.dart';
import 'package:musyn/widgets/player_sheet_route.dart';
import 'package:musyn/widgets/position_slider.dart';
import 'package:musyn/widgets/queue_list_view.dart';
import 'package:musyn/widgets/song_actions_sheet.dart';
import 'package:musyn/widgets/song_artwork.dart';

enum _PlayerPane { main, lyrics, queue }

/// BitChord-inspired unified Now Playing Player with gesture-based navigation,
/// full-height synced lyrics stage, integrated queue, and compact transport dock.
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key, this.navigationBase = '/home'});
  final String navigationBase;
  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  _PlayerPane _pane = _PlayerPane.main;
  String? _lyricTrack;
  Future<String?>? _lyrics;
  double _coverDrag = 0;
  double _horizontalDrag = 0;
  double _backDrag = 0;
  bool _downward = false;
  late final AnimationController _sleeveX = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _sleeveX.dispose();
    super.dispose();
  }

  PlayerSheetRoute? get _sheet {
    final route = ModalRoute.of(context);
    return route is PlayerSheetRoute ? route : null;
  }

  void _dismissUpdate(DragUpdateDetails details) =>
      _sheet?.dragBy(details.delta.dy, MediaQuery.sizeOf(context).height);
  void _dismissEnd(DragEndDetails details) => _sheet?.settle(
    details.primaryVelocity ?? 0,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  );

  Widget _dismissHandle() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      HapticFeedback.lightImpact();
      Navigator.pop(context);
    },
    onVerticalDragUpdate: _dismissUpdate,
    onVerticalDragEnd: _dismissEnd,
    onVerticalDragCancel: () => _sheet?.settle(0),
    child: SizedBox(
      height: 44,
      child: Center(
        child: Container(
          width: 36,
          height: 4.5,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _pane == _PlayerPane.main,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _pane != _PlayerPane.main) {
        HapticFeedback.lightImpact();
        setState(() => _pane = _PlayerPane.main);
      }
    },
    child: StreamBuilder<MediaItem?>(
      initialData: audioHandler.mediaItem.valueOrNull,
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) {
          return CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close player'),
              ),
            ),
          );
        }
        final trackKey = item.extras?['ytid']?.toString() ?? item.id;
        if (_lyricTrack != trackKey) {
          _lyricTrack = trackKey;
          _lyrics = null;
        }
        if (_pane == _PlayerPane.lyrics) {
          _lyrics ??= getSongLyrics(item.artist, item.title);
        }
        final dark = isAppDarkMode(context);

        return CupertinoPageScaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: musynCanvas(dark),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: dark ? .32 : .18,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: LayoutBuilder(
                        builder: (_, box) => FittedBox(
                          fit: BoxFit.cover,
                          child: SongArtworkWidget(
                            metadata: item,
                            size: math.max(box.maxWidth, box.maxHeight),
                            borderRadius: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _dismissHandle(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final wide = box.maxWidth > box.maxHeight * 1.3;
                          final reduced = MediaQuery.disableAnimationsOf(
                            context,
                          );

                          // Wide/Landscape layout
                          if (wide) {
                            return _buildLandscapeLayout(item, box, reduced);
                          }

                          return Column(
                            children: [
                              // Middle Stage (Sleeve, Lyrics, Queue)
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: reduced
                                      ? Duration.zero
                                      : const Duration(milliseconds: 280),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  child: KeyedSubtree(
                                    key: ValueKey(_pane),
                                    child: switch (_pane) {
                                      _PlayerPane.main => _mainSleeve(
                                        item,
                                        box,
                                        reduced,
                                      ),
                                      _PlayerPane.lyrics => _lyricsStage(item),
                                      _PlayerPane.queue => _queueStage(item),
                                    },
                                  ),
                                ),
                              ),
                              _credits(item),
                              _deck(
                                item,
                                compact:
                                    box.maxHeight < 620 ||
                                    _pane != _PlayerPane.main,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _buildLandscapeLayout(
    MediaItem item,
    BoxConstraints box,
    bool reduced,
  ) {
    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey(_pane),
              child: switch (_pane) {
                _PlayerPane.main => _mainSleeve(item, box, reduced),
                _PlayerPane.lyrics => _lyricsStage(item),
                _PlayerPane.queue => _queueStage(item),
              },
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [_credits(item), _deck(item, compact: true)],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN SLEEVE VIEW & FULL SCREEN HORIZONTAL GESTURES
  // ---------------------------------------------------------------------------
  Widget _mainSleeve(MediaItem item, BoxConstraints box, bool reduced) {
    final sleeve = math.min(
      box.maxWidth - 48,
      math.max(80, box.maxHeight - 20),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        _coverDrag = 0;
        _horizontalDrag = 0;
        _downward = false;
        _sleeveX.stop();
      },
      onPanUpdate: (details) {
        if (!_downward &&
            details.delta.dx.abs() > details.delta.dy.abs() * 1.1) {
          _horizontalDrag += details.delta.dx;
          _sleeveX.value = _horizontalDrag * 0.45;
        } else {
          _coverDrag += details.delta.dy;
          if (_coverDrag > 0 && !_downward) _downward = true;
          if (_downward) {
            _dismissUpdate(
              DragUpdateDetails(
                globalPosition: details.globalPosition,
                delta: details.delta,
                primaryDelta: details.delta.dy,
              ),
            );
          } else {
            setState(() {});
          }
        }
      },
      onPanEnd: (details) {
        final vx = details.velocity.pixelsPerSecond.dx;
        final vy = details.velocity.pixelsPerSecond.dy;
        if (_downward) {
          _dismissEnd(
            DragEndDetails(velocity: details.velocity, primaryVelocity: vy),
          );
        } else if (_coverDrag < -72 || vy < -400) {
          HapticFeedback.lightImpact();
          setState(() => _pane = _PlayerPane.queue);
        } else if (_horizontalDrag < -50 || vx < -350) {
          HapticFeedback.mediumImpact();
          unawaited(audioHandler.skipToNext());
        } else if (_horizontalDrag > 50 || vx > 350) {
          HapticFeedback.mediumImpact();
          unawaited(audioHandler.skipToPrevious());
        }
        _horizontalDrag = 0;
        _coverDrag = 0;
        if (reduced) {
          _sleeveX.value = 0;
        } else {
          _sleeveX.animateWith(
            SpringSimulation(
              SpringDescription.withDampingRatio(
                mass: 1,
                stiffness: 320,
                ratio: .85,
              ),
              _sleeveX.value,
              0,
              vx * .5,
            ),
          );
        }
      },
      onPanCancel: () {
        _sheet?.settle(0);
        _sleeveX
          ..stop()
          ..value = 0;
        _horizontalDrag = 0;
        _coverDrag = 0;
      },
      child: Center(
        child: AnimatedBuilder(
          animation: _sleeveX,
          builder: (context, child) => Transform.translate(
            offset: Offset(_sleeveX.value, 0),
            child: child,
          ),
          child: AnimatedContainer(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(
              0,
              _downward ? 0 : _coverDrag.clamp(-96.0, 0.0) * .5,
              0,
            ),
            child: Hero(
              flightShuttleBuilder: SongArtworkWidget.flightShuttle,
              tag: 'playing-art-${item.id}',
              child: SongArtworkWidget(
                metadata: item,
                size: sleeve.toDouble(),
                borderRadius: 14,
                errorWidgetIconSize: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FULL-STAGE SYNCED LYRICS VIEW
  // ---------------------------------------------------------------------------

  Widget _lyricsStage(MediaItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _backDrag = 0,
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0 || _backDrag > 0) {
          _backDrag += details.delta.dx;
        }
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_backDrag > 60 || velocity > 350) {
          HapticFeedback.lightImpact();
          setState(() => _pane = _PlayerPane.main);
        }
        _backDrag = 0;
      },
      onHorizontalDragCancel: () => _backDrag = 0,
      child: AsyncLoader<String?>(
        future: _lyrics!,
        emptyWidget: const SingleChildScrollView(
          child: ContentState(
            icon: CupertinoIcons.quote_bubble,
            title: 'No lyrics available',
            message: 'Lyrics have not been found for this track.',
          ),
        ),
        errorBuilder: (_, _, _) => SingleChildScrollView(
          child: ContentState(
            icon: CupertinoIcons.exclamationmark_bubble,
            title: 'Could not load lyrics',
            message: 'Your music is still playing.',
            actionLabel: 'Retry lyrics',
            onAction: () => setState(
              () => _lyrics = getSongLyrics(item.artist, item.title),
            ),
          ),
        ),
        builder: (context, lyrics) => SyncedLyricsView(
          metadata: item,
          lyrics: lyrics ?? '',
          isActive: true,
          isFullScreen: true,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FULL-STAGE PLAYING NEXT QUEUE VIEW
  // ---------------------------------------------------------------------------

  Widget _queueStage(MediaItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _backDrag = 0,
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0 || _backDrag > 0) {
          _backDrag += details.delta.dx;
        }
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_backDrag > 60 || velocity > 350) {
          HapticFeedback.lightImpact();
          setState(() => _pane = _PlayerPane.main);
        }
        _backDrag = 0;
      },
      onHorizontalDragCancel: () => _backDrag = 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Playing Next',
                  style: TextStyle(
                    fontFamily: MusynStyle.displayFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: CupertinoColors.white,
                  ),
                ),
                const Spacer(),
                _queueModes(),
              ],
            ),
          ),
          const Expanded(child: QueueWidget()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TRACK CREDITS (TITLE, ARTIST, LIKE, MENU)
  // ---------------------------------------------------------------------------
  Widget _credits(MediaItem item) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 16, 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MusynStyle.playerTitle(
                  CupertinoTheme.of(context).textTheme.textStyle.color!,
                ).copyWith(fontSize: _pane == _PlayerPane.main ? 22 : 16),
              ),
              const SizedBox(height: 3),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: offlineMode.value
                    ? null
                    : () {
                        final artist =
                            item.extras?['artistId']?.toString() ??
                            item.artist ??
                            '';
                        if (artist.isEmpty) return;
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        unawaited(
                          router.push(
                            '${widget.navigationBase}/artist/${Uri.encodeComponent(artist)}',
                            extra: {
                              'title': item.artist,
                              'artistId': item.extras?['artistId'],
                              'sourceSongId': item.extras?['ytid'],
                              'isArtist': true,
                            },
                          ),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    item.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MusynStyle.playerArtist(
                      CupertinoColors.secondaryLabel.resolveFrom(context),
                    ).copyWith(fontSize: _pane == _PlayerPane.main ? 16 : 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder(
          valueListenable: userLikedSongsList,
          builder: (_, _, _) {
            final id = item.extras?['ytid']?.toString() ?? item.id;
            final liked = isSongAlreadyLiked(id);
            return _button(
              liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              'Favorite',
              () => unawaited(
                updateSongLikeStatus(
                  id,
                  !liked,
                  songData: mediaItemToMap(item),
                ),
              ),
            );
          },
        ),
        _button(
          CupertinoIcons.ellipsis,
          'Track options',
          () => showSongActionsSheet(context, song: mediaItemToMap(item)),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------------------
  // FULL TRANSPORT DECK (MAIN SLEEVE VIEW)
  // ---------------------------------------------------------------------------
  Widget _deck(MediaItem item, {required bool compact}) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!(item.extras?['isLive'] ?? false))
          PositionSlider(qualityLabel: _qualityLabel(item)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _button(
              CupertinoIcons.backward_end_fill,
              'Previous track',
              () => unawaited(audioHandler.skipToPrevious()),
              size: compact ? 28 : 34,
              touch: compact ? 48 : 60,
            ),
            buildPlaybackIconButton(
              compact ? 38 : 50,
              CupertinoTheme.of(context).textTheme.textStyle.color!,
              const Color(0x00000000),
              padding: const EdgeInsets.all(8),
            ),
            _button(
              CupertinoIcons.forward_end_fill,
              'Next track',
              () => unawaited(audioHandler.skipToNext()),
              size: compact ? 28 : 34,
              touch: compact ? 48 : 60,
            ),
          ],
        ),
        if (_pane == _PlayerPane.main) ...[
          const SizedBox(height: 4),
          StreamBuilder<double>(
            initialData: audioHandler.audioPlayer.volume,
            stream: audioHandler.audioPlayer.volumeStream,
            builder: (_, snapshot) => Row(
              children: [
                const Icon(
                  CupertinoIcons.volume_down,
                  size: 20,
                  color: CupertinoColors.systemGrey,
                ),
                Expanded(
                  child: CupertinoSlider(
                    value: (snapshot.data ?? 1).clamp(0.0, 1.0),
                    onChanged: (value) =>
                        unawaited(audioHandler.audioPlayer.setVolume(value)),
                  ),
                ),
                const Icon(
                  CupertinoIcons.volume_up,
                  size: 20,
                  color: CupertinoColors.systemGrey,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _button(CupertinoIcons.quote_bubble, 'Lyrics', () {
              HapticFeedback.selectionClick();
              setState(
                () => _pane = _pane == _PlayerPane.lyrics
                    ? _PlayerPane.main
                    : _PlayerPane.lyrics,
              );
            }, selected: _pane == _PlayerPane.lyrics),
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _button(
                      CupertinoIcons.antenna_radiowaves_left_right,
                      'Playback source and quality',
                      () => showAudioSourcePicker(context, item),
                      touch: 58,
                    ),
                    Container(
                      height: 20,
                      width: .5,
                      color: CupertinoColors.systemGrey,
                    ),
                    _button(
                      CupertinoIcons.arrow_down_circle,
                      'Download options',
                      () => unawaited(
                        showDownloadPicker(context, mediaItemToMap(item), (
                          source,
                          quality,
                        ) async {
                          final ok = await makeSongOffline(
                            mediaItemToMap(item),
                            source: source,
                            quality: quality,
                          );
                          if (mounted) {
                            showToast(
                              context,
                              ok
                                  ? 'Saved to downloads'
                                  : 'Download failed. Try again.',
                            );
                          }
                        }),
                      ),
                      touch: 58,
                    ),
                  ],
                ),
              ),
            ),
            _button(CupertinoIcons.list_bullet, 'Queue', () {
              HapticFeedback.selectionClick();
              setState(
                () => _pane = _pane == _PlayerPane.queue
                    ? _PlayerPane.main
                    : _PlayerPane.queue,
              );
            }, selected: _pane == _PlayerPane.queue),
          ],
        ),
      ],
    ),
  );

  String _qualityLabel(MediaItem item) {
    final extras = item.extras ?? {};
    final source = switch (extras['resolvedSource']) {
      'offline' => 'Downloaded',
      'jiosaavn' => 'JioSaavn',
      'youtube' => 'YouTube Music',
      _ => 'Streaming',
    };
    final codec = extras['resolvedFormat']?.toString().toLowerCase() ?? '';
    final format = codec.startsWith('mp4a') || codec.contains('aac')
        ? 'AAC'
        : codec.contains('opus')
        ? 'Opus'
        : '';
    final bitrate = num.tryParse('${extras['resolvedBitrate']}');
    return [
      source,
      if (format.isNotEmpty) format,
      if (bitrate != null && bitrate > 0) '${bitrate.round()} kbps',
    ].join(' · ');
  }

  Widget _queueModes() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ValueListenableBuilder(
        valueListenable: shuffleNotifier,
        builder: (_, value, _) => _button(
          CupertinoIcons.shuffle,
          'Shuffle',
          () => unawaited(
            audioHandler.setShuffleMode(
              value
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all,
            ),
          ),
          selected: value,
        ),
      ),
      ValueListenableBuilder(
        valueListenable: repeatNotifier,
        builder: (_, value, _) => _button(
          value == AudioServiceRepeatMode.one
              ? CupertinoIcons.repeat_1
              : CupertinoIcons.repeat,
          'Repeat',
          () => unawaited(
            audioHandler.setRepeatMode(
              AudioServiceRepeatMode.values[(value.index + 1) % 3],
            ),
          ),
          selected: value != AudioServiceRepeatMode.none,
        ),
      ),
      ValueListenableBuilder(
        valueListenable: playNextSongAutomatically,
        builder: (_, value, _) => _button(
          CupertinoIcons.infinite,
          'Autoplay',
          () {
            playNextSongAutomatically.value = !value;
            unawaited(
              addOrUpdateData('settings', 'playNextSongAutomatically', !value),
            );
          },
          selected: value,
        ),
      ),
    ],
  );

  Widget _button(
    IconData icon,
    String label,
    VoidCallback action, {
    double size = 24,
    double touch = 44,
    bool selected = false,
  }) => Semantics(
    button: true,
    label: label,
    selected: selected,
    child: CupertinoButton(
      minimumSize: Size(touch, touch),
      padding: const EdgeInsets.all(8),
      onPressed: action,
      child: Icon(
        icon,
        size: size,
        color: selected
            ? CupertinoTheme.of(context).primaryColor
            : CupertinoTheme.of(context).textTheme.textStyle.color,
      ),
    ),
  );
}
