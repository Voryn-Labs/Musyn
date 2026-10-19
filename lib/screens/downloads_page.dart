import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/download_activity.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/utilities/mediaitem.dart';
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
  bool _alphabetical = false;
  bool _history = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _options() => showCupertinoModalPopup<void>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: const Text('Downloads'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(sheet);
            setState(() => _alphabetical = !_alphabetical);
          },
          child: Text(_alphabetical ? 'Sort by newest' : 'Sort by title'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(sheet);
            setState(() => _history = !_history);
          },
          child: Text(
            _history ? 'Hide recent transfers' : 'Show recent transfers',
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(sheet);
            downloadActivity.clearFinished();
          },
          child: const Text('Clear finished'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheet),
        child: const Text('Cancel'),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: AnimatedBuilder(
      animation: Listenable.merge([
        downloadActivity.jobs,
        userOfflineSongs,
        offlineMode,
        offlinePlaylistService.activeDownloadIds,
      ]),
      builder: (context, _) {
        final saved =
            userOfflineSongs.value
                .whereType<Map>()
                .where(
                  (song) => '${song['title']} ${song['artist']}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
                )
                .toList()
              ..sort(
                (a, b) => _alphabetical
                    ? '${a['title']}'.toLowerCase().compareTo(
                        '${b['title']}'.toLowerCase(),
                      )
                    : (num.tryParse('${b['dateAdded']}') ?? 0).compareTo(
                        num.tryParse('${a['dateAdded']}') ?? 0,
                      ),
              );
        final jobs = downloadActivity.jobs.value
            .where(
              (job) =>
                  _history ||
                  job.active ||
                  job.stage == DownloadStage.failed ||
                  job.stage == DownloadStage.cancelled,
            )
            .toList();
        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Downloads'),
              border: null,
              leading: Navigator.canPop(context)
                  ? CupertinoNavigationBarBackButton(
                      onPressed: () => Navigator.maybePop(context),
                    )
                  : null,
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                key: const ValueKey('download-options'),
                onPressed: _options,
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  semanticLabel: 'Download settings',
                ),
              ),
            ),
            if (userOfflineSongs.value.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    '${userOfflineSongs.value.length} songs saved on this iPhone',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: CupertinoSearchTextField(
                    controller: _search,
                    placeholder: 'Search downloads',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
            ],
            if (offlinePlaylistService.activeDownloadIds.value.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    for (final id
                        in offlinePlaylistService.activeDownloadIds.value)
                      ValueListenableBuilder(
                        valueListenable: offlinePlaylistService
                            .getProgressNotifier(id),
                        builder: (context, progress, _) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.music_albums, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      offlinePlaylistService.activeTitles[id] ??
                                          'Playlist download',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${progress.completed} of ${progress.total} saved${progress.failed > 0 ? ' · ${progress.failed} failed' : ''}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CupertinoButton(
                                onPressed: progress.isCancelled
                                    ? null
                                    : () => offlinePlaylistService
                                          .cancelDownload(context, id),
                                child: Text(
                                  progress.isCancelled
                                      ? 'Cancelling…'
                                      : 'Cancel playlist',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (jobs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _history ? 'Recent transfers' : 'Downloading',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_history)
                        CupertinoButton(
                          onPressed: downloadActivity.clearFinished,
                          child: const Text('Clear finished'),
                        ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: jobs.length,
                itemBuilder: (_, index) => _transfer(jobs[index]),
              ),
            ],
            if (saved.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      CupertinoButton(
                        onPressed: () => _play(saved),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.play_fill, size: 18),
                            SizedBox(width: 8),
                            Text('Play All'),
                          ],
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        onPressed: () {
                          final shuffled = List<Map>.from(saved)..shuffle();
                          _play(shuffled);
                        },
                        child: const Icon(
                          CupertinoIcons.shuffle,
                          semanticLabel: 'Shuffle downloads',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: saved.length,
                itemBuilder: (_, index) => SongTile(
                  song: saved[index],
                  onTap: () => _play(saved, index: index),
                ),
              ),
            ] else
              SliverToBoxAdapter(
                child: ContentState(
                  icon: CupertinoIcons.arrow_down_circle,
                  title: _query.isNotEmpty
                      ? 'No matching downloads'
                      : 'Take your music with you',
                  message: _query.isNotEmpty
                      ? 'Try another title or artist.'
                      : 'Tap Download on the Musyn player. Your saved music is always here, even offline.',
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Musyn · Voryn Labs',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ),
            const SliverMiniPlayerBottomSpace(),
          ],
        );
      },
    ),
  );

  void _play(List<Map> saved, {int index = 0}) {
    unawaited(
      audioHandler.playPlaylistSong(
        playlist: {'title': 'Downloads', 'list': saved},
        songIndex: index,
      ),
    );
  }

  Widget _transfer(DownloadJob job) {
    final failed =
        job.stage == DownloadStage.failed ||
        job.stage == DownloadStage.cancelled;
    final label = switch (job.stage) {
      DownloadStage.queued => 'Waiting',
      DownloadStage.cancelling => 'Cancelling…',
      DownloadStage.failed => 'Download failed',
      DownloadStage.cancelled => 'Cancelled',
      DownloadStage.saved => 'Saved to device',
      DownloadStage.downloading =>
        job.progress == null
            ? 'Downloading…'
            : '${(job.progress! * 100).floor()}%',
    };
    final provider = switch (job.resolvedSource ?? job.source) {
      'saavn' || 'jiosaavn' => 'JioSaavn',
      'youtube' => 'YouTube Music',
      _ => 'Automatic source',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          SongArtworkWidget(
            size: 44,
            metadata: mapToMediaItem(job.song),
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.song['title']?.toString() ?? 'Track',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$label · $provider',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: failed
                        ? CupertinoColors.systemRed
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                if (job.stage == DownloadStage.downloading &&
                    job.progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: SizedBox(
                      height: 2,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: job.progress,
                        child: ColoredBox(
                          color: CupertinoTheme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (job.active && job.canCancel)
            Semantics(
              label: 'Cancel download',
              button: true,
              child: CupertinoButton(
                key: ValueKey('cancel-download-${job.id}'),
                onPressed: job.stage == DownloadStage.cancelling
                    ? null
                    : () => downloadActivity.cancel(job.id),
                child: const Icon(CupertinoIcons.xmark_circle),
              ),
            )
          else if (failed)
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
    );
  }
}
