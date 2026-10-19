import 'package:flutter/cupertino.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/utilities/offline_playlist_dialogs.dart';

class PlaylistDownloadButton extends StatefulWidget {
  const PlaylistDownloadButton({
    super.key,
    required this.playlistId,
    required this.resolvePlaylist,
    this.songs,
    this.requireSnapshotMatch = false,
  });

  final String playlistId;
  final Future<Map?> Function() resolvePlaylist;
  final List? songs;
  final bool requireSnapshotMatch;

  @override
  State<PlaylistDownloadButton> createState() => _PlaylistDownloadButtonState();
}

class _PlaylistDownloadButtonState extends State<PlaylistDownloadButton> {
  bool _isResolving = false;

  String get playlistId => widget.playlistId;

  bool get _isOffline {
    final songs = widget.songs;
    if (songs == null) {
      return offlinePlaylistService.isPlaylistDownloaded(playlistId);
    }
    if (!isPlaylistFullyOffline(songs)) return false;
    if (!widget.requireSnapshotMatch) return true;

    final snapshot = offlinePlaylistService.getOfflinePlaylist(playlistId);
    if (snapshot == null) return false;
    final snapshotIds = (snapshot['list'] as List? ?? const [])
        .map((song) => song['ytid'])
        .toSet();
    return songs.every((song) => snapshotIds.contains(song['ytid']));
  }

  @override
  Widget build(BuildContext context) {
    if (playlistId.isEmpty) return const SizedBox.shrink();

    final isDark = isAppDarkMode(context);

    return ValueListenableBuilder<List>(
      valueListenable: userOfflineSongs,
      builder: (context, _, __) => ValueListenableBuilder<List>(
        valueListenable: offlinePlaylistService.offlinePlaylists,
        builder: (context, __, ___) {
          if (_isOffline) {
            return CupertinoButton(
              padding: const EdgeInsets.all(10),
              color: CupertinoTheme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(22),
              onPressed: () =>
                  showRemoveOfflinePlaylistDialog(context, playlistId),
              child: Icon(
                CupertinoIcons.arrow_down_circle_fill,
                color: CupertinoTheme.of(context).primaryContrastingColor,
                size: 20,
              ),
            );
          }

          return ValueListenableBuilder<DownloadProgress>(
            valueListenable: offlinePlaylistService.getProgressNotifier(
              playlistId,
            ),
            builder: (context, progress, _) {
              if (offlinePlaylistService.isPlaylistDownloading(playlistId)) {
                return _buildProgress(context, progress);
              }

              if (offlineMode.value) return const SizedBox.shrink();

              if (_isResolving) {
                return const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }

              return CupertinoButton(
                padding: const EdgeInsets.all(10),
                color: musynSecondarySurface(isDark),
                borderRadius: BorderRadius.circular(22),
                onPressed: () => _download(context),
                child: Icon(
                  CupertinoIcons.arrow_down_to_line,
                  size: 20,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProgress(BuildContext context, DownloadProgress progress) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          progress.isCancelled
              ? 'Stopping…'
              : '${progress.completed}/${progress.total}'
                    '${progress.failed > 0 ? ' · ${progress.failed} failed' : ''}',
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(width: 6),
        CupertinoButton(
          padding: const EdgeInsets.all(10),
          onPressed: progress.isCancelled
              ? null
              : () =>
                    offlinePlaylistService.cancelDownload(context, playlistId),
          child: progress.isCancelled
              ? const CupertinoActivityIndicator()
              : const Icon(
                  CupertinoIcons.stop_circle,
                  semanticLabel: 'Cancel download',
                ),
        ),
      ],
    );
  }

  Future<void> _download(BuildContext context) async {
    if (_isResolving) return;

    setState(() => _isResolving = true);
    Map? playlist;
    try {
      playlist = await widget.resolvePlaylist();
    } catch (_) {
      if (context.mounted) showToast(context, 'Error loading playlist');
      return;
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
    if (!context.mounted) return;

    if (playlist == null) {
      showToast(context, 'Error loading playlist');
      return;
    }

    await offlinePlaylistService.downloadPlaylist(context, playlist);
  }
}
