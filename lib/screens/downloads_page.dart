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
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
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
              largeTitle: const Text('Downloads'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final id
                          in offlinePlaylistService.activeDownloadIds.value)
                        ValueListenableBuilder(
                          valueListenable: offlinePlaylistService
                              .getProgressNotifier(id),
                          builder: (context, progress, _) => CupertinoListTile(
                            title: Text(
                              offlinePlaylistService.activeTitles[id] ??
                                  'Playlist download',
                            ),
                            subtitle: Text(
                              '${progress.completed} of ${progress.total} saved · ${progress.failed} failed',
                            ),
                            trailing: CupertinoButton(
                              onPressed: progress.isCancelled
                                  ? null
                                  : () => offlinePlaylistService.cancelDownload(
                                      context,
                                      id,
                                    ),
                              child: Text(
                                progress.isCancelled
                                    ? 'Cancelling…'
                                    : 'Cancel playlist',
                              ),
                            ),
                          ),
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
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Saved tracks · ${userOfflineSongs.value.length}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (userOfflineSongs.value.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
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

  Widget _job(DownloadJob job) {
    final stage = switch (job.stage) {
      DownloadStage.queued => 'Waiting to download',
      DownloadStage.downloading =>
        job.progress == null
            ? job.received > 0
                  ? '${(job.received / 1048576).toStringAsFixed(1)} MB downloaded'
                  : 'Preparing or downloading audio'
            : '${(job.progress! * 100).floor()}% · ${(job.received / 1048576).toStringAsFixed(1)} MB',
      DownloadStage.cancelling => 'Cancelling…',
      DownloadStage.saved => 'Saved to device',
      DownloadStage.failed => 'Download failed',
      DownloadStage.cancelled => 'Download cancelled',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: musynElevatedSurface(isAppDarkMode(context)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.song['title']?.toString() ?? 'Track',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (job.active && job.canCancel)
                  CupertinoButton(
                    onPressed: job.stage == DownloadStage.cancelling
                        ? null
                        : () => downloadActivity.cancel(job.id),
                    child: const Text('Cancel'),
                  )
                else if (job.stage == DownloadStage.failed ||
                    job.stage == DownloadStage.cancelled)
                  CupertinoButton(
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
                    child: const Text('Retry'),
                  ),
              ],
            ),
            Text(
              stage,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemGrey,
              ),
            ),
            if (job.active && !job.canCancel)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Part of a playlist download',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            if (job.stage == DownloadStage.downloading && job.progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      children: [
                        Container(
                          color: CupertinoColors.systemGrey.withValues(
                            alpha: .2,
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: job.progress,
                          child: Container(
                            color: CupertinoTheme.of(context).primaryColor,
                          ),
                        ),
                      ],
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
