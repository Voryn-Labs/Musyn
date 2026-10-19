import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/download_activity.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/mediaitem.dart' show mapToMediaItem;
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/song_artwork.dart';
import 'package:musyn/widgets/song_tile.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  String _query = '';
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _alphabetical = false;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: musynCanvas(isAppDarkMode(context)),
    child: AnimatedBuilder(
      animation: Listenable.merge([
        downloadActivity.jobs,
        offlineMode,
        userOfflineSongs,
        offlinePlaylistService.activeDownloadIds,
      ]),
      builder: (context, _) {
        final saved = userOfflineSongs.value
            .whereType<Map>()
            .where(
              (song) => '${song['title']} ${song['artist']}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
            )
            .toList();
        if (_alphabetical) {
          saved.sort(
            (a, b) => '${a['title']}'.toLowerCase().compareTo(
              '${b['title']}'.toLowerCase(),
            ),
          );
        } else {
          saved.sort(
            (a, b) => (num.tryParse('${b['dateAdded']}') ?? 0).compareTo(
              num.tryParse('${a['dateAdded']}') ?? 0,
            ),
          );
        }
        final jobs = downloadActivity.jobs.value;
        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverNavigationBar(
              leading: Navigator.canPop(context)
                  ? CupertinoNavigationBarBackButton(
                      color: CupertinoTheme.of(context).primaryColor,
                      onPressed: () => Navigator.maybePop(context),
                    )
                  : null,
              largeTitle: const Text(
                'Downloads',
                style: TextStyle(
                  fontFamily: MusynStyle.displayFont,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              border: null,
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _alphabetical = !_alphabetical),
                child: Icon(
                  CupertinoIcons.sort_down,
                  semanticLabel: _alphabetical
                      ? 'Sort by newest'
                      : 'Sort by title',
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              ),
            ),
            if (offlinePlaylistService.activeDownloadIds.value.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    children: [
                      for (final id in offlinePlaylistService.activeDownloadIds.value)
                        ValueListenableBuilder(
                          valueListenable: offlinePlaylistService.getProgressNotifier(id),
                          builder: (context, progress, _) {
                            final fraction = progress.total > 0
                                ? (progress.completed / progress.total).clamp(0.0, 1.0)
                                : 0.0;
                            final isDark = isAppDarkMode(context);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: musynElevatedSurface(isDark),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: MusynStyle.appleRed.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            CupertinoIcons.music_albums,
                                            color: MusynStyle.appleRed,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              offlinePlaylistService.activeTitles[id] ?? 'Playlist download',
                                              style: TextStyle(
                                                fontFamily: MusynStyle.displayFont,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -0.2,
                                                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${progress.completed} of ${progress.total} saved · ${progress.failed} failed',
                                              style: const TextStyle(
                                                fontFamily: MusynStyle.uiFont,
                                                fontSize: 12,
                                                color: CupertinoColors.systemGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        onPressed: progress.isCancelled
                                            ? null
                                            : () => offlinePlaylistService.cancelDownload(context, id),
                                        child: Text(
                                          progress.isCancelled ? 'Cancelling…' : 'Cancel playlist',
                                          style: const TextStyle(
                                            fontFamily: MusynStyle.uiFont,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3.5),
                                    child: Container(
                                      height: 7,
                                      width: double.infinity,
                                      color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
                                      child: TweenAnimationBuilder<double>(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        tween: Tween<double>(begin: 0, end: fraction),
                                        builder: (context, val, _) => FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: val,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(3.5),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF375F),
                                                  MusynStyle.appleRed,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            if (jobs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Transfer activity',
                          style: TextStyle(
                            fontFamily: MusynStyle.displayFont,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        onPressed: jobs.any((job) => !job.active)
                            ? downloadActivity.clearFinished
                            : null,
                        child: const Text('Clear finished'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: jobs.length,
                itemBuilder: (context, index) => _job(jobs[index]),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Text(
                  'Saved tracks · ${userOfflineSongs.value.length}',
                  style: const TextStyle(
                    fontFamily: MusynStyle.displayFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            if (saved.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: MusynStyle.appleRed,
                          borderRadius: BorderRadius.circular(20),
                          onPressed: () => audioHandler.playPlaylistSong(
                            playlist: {'title': 'Downloads', 'list': saved},
                            songIndex: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.play_fill, size: 15, color: CupertinoColors.white),
                              SizedBox(width: 6),
                              Text(
                                'Play All',
                                style: TextStyle(
                                  fontFamily: MusynStyle.uiFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: isAppDarkMode(context)
                              ? const Color(0x1FFFFFFF)
                              : const Color(0x0F000000),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: () {
                            final shuffled = List.from(saved)..shuffle();
                            audioHandler.playPlaylistSong(
                              playlist: {'title': 'Downloads', 'list': shuffled},
                              songIndex: 0,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.shuffle,
                                size: 16,
                                color: isAppDarkMode(context)
                                    ? CupertinoColors.white
                                    : CupertinoColors.black,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Shuffle',
                                style: TextStyle(
                                  fontFamily: MusynStyle.uiFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isAppDarkMode(context)
                                    ? CupertinoColors.white
                                    : CupertinoColors.black,
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
            if (userOfflineSongs.value.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: CupertinoSearchTextField(
                    controller: _search,
                    placeholder: 'Search downloads',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
            if (saved.isNotEmpty)
              SliverList.builder(
                itemCount: saved.length,
                itemBuilder: (context, index) => SongTile(
                  song: saved[index],
                  onTap: () => audioHandler.playPlaylistSong(
                    playlist: {'title': 'Downloads', 'list': saved},
                    songIndex: index,
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ContentState(
                  icon: CupertinoIcons.arrow_down_circle,
                  title: _query.isNotEmpty
                      ? 'No matching downloads'
                      : 'Take your music with you',
                  message: _query.isNotEmpty
                      ? 'Try another title or artist.'
                      : 'Download a track from its options menu. Saved music plays without a connection.',
                  actionLabel: _query.isNotEmpty
                      ? 'Clear filter'
                      : offlineMode.value
                      ? 'Go online to find music'
                      : 'Find music',
                  onAction: () {
                    if (_query.isNotEmpty) {
                      _search.clear();
                      setState(() => _query = '');
                    } else {
                      if (offlineMode.value) {
                        offlineMode.value = false;
                        unawaited(
                          addOrUpdateData('settings', 'offlineMode', false),
                        );
                      }
                      context.go('/search');
                    }
                  },
                ),
              ),
            const SliverMiniPlayerBottomSpace(),
          ],
        );
      },
    ),
  );

  Widget _job(DownloadJob job) => _DownloadJobCard(job: job);
}

class _DownloadJobCard extends StatefulWidget {
  const _DownloadJobCard({required this.job});
  final DownloadJob job;

  @override
  State<_DownloadJobCard> createState() => _DownloadJobCardState();
}

class _DownloadJobCardState extends State<_DownloadJobCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final isDark = isAppDarkMode(context);
    final title = job.song['title']?.toString() ?? 'Track';
    final artist = job.song['artist']?.toString() ?? 'Musyn';
    final progress = job.progress;

    final stage = switch (job.stage) {
      DownloadStage.queued => 'Waiting to download',
      DownloadStage.downloading =>
        job.received > 0
            ? '${(job.received / 1048576).toStringAsFixed(1)} MB downloaded'
            : 'Downloading audio',
      DownloadStage.cancelling => 'Cancelling…',
      DownloadStage.saved => 'Saved to device',
      DownloadStage.failed => 'Download failed',
      DownloadStage.cancelled => 'Download cancelled',
    };

    final isSaavn = job.source == 'saavn' ||
        job.source == 'jiosaavn' ||
        job.song['catalogOrigin'] == 'saavn';
    final sourceBadge = isSaavn ? 'JioSaavn' : 'YouTube';
    final qualityBadge = job.quality != null ? '${job.quality}k' : (isSaavn ? '320k' : '160k');
    final badgeColor = isSaavn ? CupertinoColors.systemGreen : const Color(0xFFFF0033);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: musynElevatedSurface(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x28000000) : const Color(0x0A000000),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: SongArtworkWidget(
                      metadata: mapToMediaItem(job.song),
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MusynStyle.displayFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: MusynStyle.uiFont,
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (job.active && job.canCancel)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: job.stage == DownloadStage.cancelling
                        ? null
                        : () => downloadActivity.cancel(job.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x24FFFFFF) : const Color(0x12000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: MusynStyle.uiFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  )
                else if (job.stage == DownloadStage.failed ||
                    job.stage == DownloadStage.cancelled)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      downloadActivity.dismiss(job.id);
                      unawaited(
                        makeSongOffline(
                          job.song,
                          source: job.source,
                          quality: job.quality,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: MusynStyle.appleRed.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_clockwise,
                            size: 12,
                            color: MusynStyle.appleRed,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Retry',
                            style: TextStyle(
                              fontFamily: MusynStyle.uiFont,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MusynStyle.appleRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSaavn ? CupertinoIcons.waveform : CupertinoIcons.play_rectangle_fill,
                        size: 11,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$sourceBadge · $qualityBadge',
                        style: TextStyle(
                          fontFamily: MusynStyle.uiFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                if (progress != null && job.stage == DownloadStage.downloading)
                  Text(
                    '${(progress * 100).floor()}%',
                    style: TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? CupertinoColors.white : CupertinoColors.black,
                    ),
                  ),
              ],
            ),
            if (job.active && !job.canCancel)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Part of a playlist download',
                  style: TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            if (job.stage == DownloadStage.downloading)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 8,
                    width: double.infinity,
                    color: isDark ? const Color(0x29FFFFFF) : const Color(0x14000000),
                    child: progress == null
                        ? AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) => FractionallySizedBox(
                              alignment: Alignment(-1.0 + (_pulseController.value * 2.0), 0),
                              widthFactor: 0.40,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0x33FF2D55),
                                      MusynStyle.appleRed,
                                      Color(0x33FF2D55),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(
                              begin: 0,
                              end: progress.clamp(0.0, 1.0),
                            ),
                            builder: (context, val, _) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: val,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF375F),
                                      MusynStyle.appleRed,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
