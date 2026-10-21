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
import 'package:musyn/services/download_activity.dart';
import 'package:musyn/services/lock_screen_lyrics.dart';
import 'package:musyn/services/motion_artwork.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/vocal_reduction.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/async_loader.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/mediaitem.dart';
import 'package:musyn/utilities/playlist_dialogs.dart';
import 'package:musyn/utilities/song_info_dialog.dart';
import 'package:musyn/widgets/audio_route_button.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/motion_artwork_view.dart';
import 'package:musyn/widgets/now_playing/source_picker_sheet.dart';
import 'package:musyn/widgets/now_playing/synced_lyrics_view.dart';
import 'package:musyn/widgets/playback_icon_button.dart';
import 'package:musyn/widgets/player_options_button.dart';
import 'package:musyn/widgets/player_sheet_route.dart';
import 'package:musyn/widgets/position_slider.dart';
import 'package:musyn/widgets/queue_list_view.dart';
import 'package:musyn/widgets/sleep_timer_picker.dart';
import 'package:musyn/widgets/song_artwork.dart';
import 'package:musyn/widgets/vocal_reduction_controls.dart';

enum _PlayerPane { main, lyrics, queue }

/// Music player with gesture-based navigation,
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
  bool _singAlong = false;
  String? _lyricTrack;
  String? _vocalSelection;
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

  Future<void> _chooseLockLyrics() async {
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: const Text('Lock-screen lyrics'),
        message: const Text(
          'Timed lyrics can replace the artist line or artwork. Tap the lock-screen artwork to expand it. iOS controls the final presentation.',
        ),
        actions: [
          for (final option in [
            0,
            1,
            if (MotionArtwork.instance.supported) ...[2, 3],
          ])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheet, option),
              child: Text(
                [
                  'Off',
                  'Artist line',
                  'Artwork',
                  'Artist line and artwork',
                ][option],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selected == null) return;
    lockScreenLyricsEnabled.value = selected == 1 || selected == 3;
    lockScreenArtworkLyricsEnabled.value = selected >= 2;
    await Future.wait([
      addOrUpdateData(
        'settings',
        'lockScreenLyrics',
        lockScreenLyricsEnabled.value,
      ),
      addOrUpdateData(
        'settings',
        'lockScreenArtworkLyrics',
        lockScreenArtworkLyricsEnabled.value,
      ),
    ]);
    if (mounted) setState(() {});
  }

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
        if (_pane == _PlayerPane.lyrics ||
            MediaQuery.orientationOf(context) == Orientation.landscape) {
          _lyrics ??= getSongLyrics(item.artist, item.title);
        }
        final vocalKey = VocalReductionController.identity(item);
        if (_vocalSelection != vocalKey) {
          _vocalSelection = vocalKey;
          _singAlong = false;
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
    _lyrics ??= getSongLyrics(item.artist, item.title);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
    Widget controls() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.isLive != true)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: PositionSlider(qualityLabel: _qualityLabel(item)),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            _button(
              CupertinoIcons.backward_end_fill,
              'Previous track',
              () => unawaited(audioHandler.skipToPrevious()),
            ),
            buildPlaybackIconButton(
              30,
              CupertinoTheme.of(context).textTheme.textStyle.color!,
              const Color(0x00000000),
              padding: const EdgeInsets.all(8),
            ),
            _button(
              CupertinoIcons.forward_end_fill,
              'Next track',
              () => unawaited(audioHandler.skipToNext()),
            ),
            _downloadControl(item),
            _button(
              CupertinoIcons.list_bullet,
              'Queue',
              () => setState(
                () => _pane = _pane == _PlayerPane.queue
                    ? _PlayerPane.lyrics
                    : _PlayerPane.queue,
              ),
              selected: _pane == _PlayerPane.queue,
            ),
          ],
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: largeText
                ? SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 96,
                          child: LayoutBuilder(
                            builder: (_, art) =>
                                _mainSleeve(item, art, reduced),
                          ),
                        ),
                        _credits(item),
                        controls(),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (_, art) => _mainSleeve(item, art, reduced),
                        ),
                      ),
                      _credits(item),
                      controls(),
                    ],
                  ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 20),
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: AnimatedSwitcher(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_pane == _PlayerPane.queue),
                child: _pane == _PlayerPane.queue
                    ? _queueStage(item)
                    : _lyricsStage(item),
              ),
            ),
          ),
        ],
      ),
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
            child: _playbackSleeve(
              reduced,
              Hero(
                flightShuttleBuilder: SongArtworkWidget.flightShuttle,
                tag: 'playing-art-${item.id}',
                child: AnimatedSwitcher(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: MotionArtworkView(
                    key: ValueKey(item.id),
                    item: item,
                    size: sleeve.toDouble(),
                    child: SongArtworkWidget(
                      metadata: item,
                      size: sleeve.toDouble(),
                      errorWidgetIconSize: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _playbackSleeve(bool reduced, Widget child) =>
      StreamBuilder<PlaybackState>(
        initialData: audioHandler.playbackState.value,
        stream: audioHandler.playbackState.distinct(
          (a, b) => a.playing == b.playing,
        ),
        builder: (context, state) => AnimatedScale(
          key: const ValueKey('playback-artwork-scale'),
          scale: state.data?.playing == true ? 1 : .92,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      );

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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _singAlong ? 'Sing along' : 'Lyrics',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Semantics(
                  label: 'Sing along mode',
                  selected: _singAlong,
                  child: CupertinoButton(
                    key: const ValueKey('sing-along-toggle'),
                    padding: const EdgeInsets.all(10),
                    onPressed: () {
                      setState(() => _singAlong = !_singAlong);
                      unawaited(
                        _singAlong
                            ? vocalReduction.enable(item)
                            : vocalReduction.disable(),
                      );
                    },
                    child: Icon(
                      _singAlong ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_singAlong) VocalReductionControls(item: item),
          Expanded(
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
                singAlong: _singAlong,
              ),
            ),
          ),
        ],
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
                const Expanded(
                  child: Text(
                    'Playing Next',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: MusynStyle.displayFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
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
        PlayerOptionsButton(
          trackId: item.id,
          options: [
            PlayerOption(
              'Sing along',
              'mic',
              () => setState(() {
                _pane = _PlayerPane.lyrics;
                _singAlong = true;
                unawaited(vocalReduction.enable(item));
              }),
              selected: _singAlong && _pane == _PlayerPane.lyrics,
            ),
            PlayerOption(
              'Lock-screen lyrics',
              'quote.bubble',
              _chooseLockLyrics,
              selected:
                  lockScreenLyricsEnabled.value ||
                  lockScreenArtworkLyricsEnabled.value,
            ),
            if (!offlineMode.value)
              PlayerOption(
                'Add to Playlist',
                'text.badge.plus',
                () => showAddToPlaylistDialog(
                  context,
                  song: mediaItemToMap(item),
                ),
              ),
            PlayerOption(
              'Playback source',
              'waveform',
              () => showAudioSourcePicker(context, item),
            ),
            PlayerOption(
              'Sleep timer',
              'moon',
              () => showSleepTimerPicker(context),
            ),
            PlayerOption(
              'Track details',
              'info.circle',
              () => showSongInfoDialog(context, mediaItemToMap(item)),
            ),
          ],
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
                    activeColor: CupertinoTheme.of(
                      context,
                    ).textTheme.textStyle.color,
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
            _downloadControl(item),
            const AudioRouteButton(),
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

  Widget _downloadControl(MediaItem item) => ValueListenableBuilder(
    valueListenable: downloadActivity.jobs,
    builder: (context, jobs, _) {
      final id = item.extras?['ytid']?.toString() ?? item.id;
      final active = jobs.any(
        (job) => job.active && job.song['ytid']?.toString() == id,
      );
      final saved = hasPlayableOfflineFile(id);
      return _button(
        saved
            ? CupertinoIcons.checkmark_circle_fill
            : CupertinoIcons.arrow_down_circle,
        active
            ? 'Downloading'
            : saved
            ? 'Downloaded'
            : 'Download track',
        active ? null : () => unawaited(_download(item)),
        selected: saved,
      );
    },
  );

  Future<void> _download(MediaItem item) async {
    final id = item.extras?['ytid']?.toString() ?? item.id;
    if (hasPlayableOfflineFile(id)) {
      showToast(context, 'Already downloaded');
      return;
    }
    showToast(context, 'Downloading…');
    final ok = await makeSongOffline(mediaItemToMap(item));
    if (mounted)
      showToast(
        context,
        ok ? 'Saved to downloads' : 'Download failed. Try again.',
      );
  }

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
    VoidCallback? action, {
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
