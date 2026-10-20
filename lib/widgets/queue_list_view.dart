import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/widgets/confirmation_dialog.dart';
import 'package:musyn/widgets/no_artwork_cube.dart';

class QueueWidget extends StatefulWidget {
  const QueueWidget({super.key, this.isBottomSheet = false});

  final bool isBottomSheet;

  @override
  State<QueueWidget> createState() => _QueueWidgetState();
}

class _QueueWidgetState extends State<QueueWidget> {
  List<Map> _queue = [];
  late StreamSubscription<List<Map>> _subscription;
  bool _hasScrolledToInitial = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _subscription = audioHandler.queueAsMapStream.listen((queue) {
      if (mounted) {
        setState(() {
          _queue = List<Map>.from(queue);
        });
        if (!_hasScrolledToInitial && queue.isNotEmpty) {
          _hasScrolledToInitial = true;
          _scrollToCurrentSong();
        }
      }
    });
    audioHandler.currentPlayingYtid.addListener(_onPlayingTrackChanged);
  }

  void _onPlayingTrackChanged() {
    if (mounted) setState(() {});
  }

  void _scrollToCurrentSong() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final currentIndex = audioHandler.currentQueueIndex;
      if (currentIndex <= 0) return;
      const estimatedItemHeight = 64.0;
      final targetOffset = currentIndex * estimatedItemHeight;
      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    audioHandler.currentPlayingYtid.removeListener(_onPlayingTrackChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final currentIndex = audioHandler.currentQueueIndex;

    if (widget.isBottomSheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, isDark, compact: true),
          _buildBottomSheetContent(context, isDark, currentIndex),
        ],
      );
    }

    return Column(
      children: [
        _buildHeader(context, isDark, compact: false),
        Container(
          height: 0.5,
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Expanded(
          child: _queue.isEmpty
              ? _buildEmptyState(context, isDark)
              : _buildList(context, isDark, currentIndex),
        ),
      ],
    );
  }

  void _confirmClearQueue(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => ConfirmationDialog(
        confirmationMessage: 'Clear all upcoming tracks from queue?',
        submitMessage: 'Clear',
        isDangerous: true,
        onCancel: () => Navigator.pop(context),
        onSubmit: () {
          Navigator.pop(context);
          audioHandler.clearQueue();
          if (widget.isBottomSheet) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark, {
    required bool compact,
  }) {
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
          : const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoTheme.of(
                context,
              ).primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.list_bullet,
              color: CupertinoTheme.of(context).primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Playing Next',
                  style: TextStyle(
                    fontFamily: MusynStyle.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: titleColor,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  '${_queue.length} songs',
                  style: const TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          if (_queue.isNotEmpty)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              onPressed: () => _confirmClearQueue(context),
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(
    BuildContext context,
    bool isDark,
    int currentIndex,
  ) {
    if (_queue.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Queue is empty',
          style: TextStyle(
            fontFamily: MusynStyle.uiFont,
            color: CupertinoColors.systemGrey,
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.54,
      child: _buildList(context, isDark, currentIndex, closeOnTap: true),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: musynSecondarySurface(isDark),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.music_note,
                color: CupertinoColors.systemGrey,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No upcoming tracks in queue',
              style: TextStyle(
                fontFamily: MusynStyle.uiFont,
                color: CupertinoColors.systemGrey,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    bool isDark,
    int currentIndex, {
    bool closeOnTap = false,
  }) {
    final hasNowPlaying = currentIndex >= 0 && currentIndex < _queue.length;
    final nowPlayingSong = hasNowPlaying ? _queue[currentIndex] : null;

    final upcomingStart = hasNowPlaying ? currentIndex + 1 : 0;
    final upcomingSongs = upcomingStart < _queue.length
        ? _queue.sublist(upcomingStart)
        : <Map>[];

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (nowPlayingSong != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: _buildSectionLabel('NOW PLAYING'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _QueueTile(
                key: ValueKey('np_${nowPlayingSong['ytid']}_$currentIndex'),
                song: nowPlayingSong,
                index: currentIndex,
                isCurrentSong: true,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (closeOnTap) Navigator.pop(context);
                },
                onRemove: () => audioHandler.removeFromQueue(currentIndex),
              ),
            ),
          ),
        ],
        if (upcomingSongs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: _buildSectionLabel(
                'NEXT IN QUEUE • ${upcomingSongs.length}',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverReorderableList(
              itemCount: upcomingSongs.length,
              onReorderItem: (oldIndex, newIndex) {
                final fullOldIndex = upcomingStart + oldIndex;
                final fullTargetIndex = upcomingStart + newIndex;
                audioHandler.reorderQueue(fullOldIndex, fullTargetIndex);
              },
              itemBuilder: (context, index) {
                final song = upcomingSongs[index];
                final fullIndex = upcomingStart + index;
                final entryKey = 'up_${song['ytid']}_$fullIndex';

                return ReorderableDelayedDragStartListener(
                  key: ValueKey(entryKey),
                  index: index,
                  child: _QueueTile(
                    song: song,
                    index: fullIndex,
                    isCurrentSong: false,
                    isDark: isDark,
                    showDragHandle: true,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      audioHandler.skipToSong(fullIndex);
                      if (closeOnTap) Navigator.pop(context);
                    },
                    onRemove: () => audioHandler.removeFromQueue(fullIndex),
                  ),
                );
              },
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: ValueListenableBuilder(
              valueListenable: playNextSongAutomatically,
              builder: (_, enabled, _) => enabled
                  ? _buildAutoplayCard(isDark)
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: MusynStyle.uiFont,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: CupertinoColors.systemGrey,
        decoration: TextDecoration.none,
      ),
    );
  }

  Widget _buildAutoplayCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: musynElevatedSurface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.infinite,
            color: CupertinoTheme.of(context).primaryColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continuous Autoplay Active',
                  style: TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Similar tracks keep playing when your queue finishes.',
                  style: TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 11,
                    color: CupertinoColors.systemGrey,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrentSong,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
    this.showDragHandle = false,
  });

  final Map song;
  final int index;
  final bool isCurrentSong;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final title = song['title']?.toString() ?? 'Track';
    final artist = song['artist']?.toString() ?? 'Artist';
    final image =
        song['image']?.toString() ?? song['lowResImage']?.toString() ?? '';
    final isLocalFile = image.startsWith('/') || image.startsWith('file://');
    final activeColor = CupertinoTheme.of(context).primaryColor;
    final titleColor = isCurrentSong
        ? activeColor
        : (isDark ? CupertinoColors.white : CupertinoColors.black);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCurrentSong
            ? activeColor.withValues(alpha: 0.12)
            : musynElevatedSurface(isDark),
        borderRadius: BorderRadius.circular(10),
        border: isCurrentSong
            ? Border.all(color: activeColor.withValues(alpha: 0.35), width: 0.8)
            : null,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: isLocalFile
                            ? Image.file(
                                File(image.replaceFirst('file://', '')),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const NullArtworkWidget(
                                      iconSize: 18,
                                      size: 44,
                                    ),
                              )
                            : image.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: image,
                                fit: BoxFit.cover,
                                memCacheWidth: 88,
                                errorWidget: (_, __, ___) =>
                                    const NullArtworkWidget(
                                      iconSize: 18,
                                      size: 44,
                                    ),
                              )
                            : const NullArtworkWidget(iconSize: 18, size: 44),
                      ),
                      if (isCurrentSong)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(
                            child: Icon(
                              CupertinoIcons.waveform,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: MusynStyle.uiFont,
                        fontSize: 14,
                        fontWeight: isCurrentSong
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: titleColor,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      style: const TextStyle(
                        fontFamily: MusynStyle.uiFont,
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: onRemove,
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              if (showDragHandle) ...[
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.bars,
                  size: 18,
                  color: CupertinoColors.systemGrey,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
