import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/playlist_bar.dart';
import 'package:musyn/widgets/playlist_cube.dart';

class PlaylistCollectionGrid extends StatelessWidget {
  const PlaylistCollectionGrid({super.key, required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    final usable = items
        .where(
          (item) =>
              (item['ytid'] ?? item['playlistId'] ?? '').toString().isNotEmpty,
        )
        .toList();
    if (usable.isEmpty)
      return const SliverToBoxAdapter(
        child: ContentState(
          title: 'No playlists available',
          message: 'Pull down to refresh this catalogue.',
        ),
      );
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      sliver: SliverLayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = scale > 1.4
              ? 1
              : box.crossAxisExtent > 650
              ? 3
              : 2;
          final width = (box.crossAxisExtent - (columns - 1) * 14) / columns;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              mainAxisExtent: width + 72 * scale,
            ),
            itemCount: usable.length,
            itemBuilder: (context, index) {
              final playlist = usable[index];
              final id = (playlist['ytid'] ?? playlist['playlistId'])
                  .toString();
              return GestureDetector(
                onLongPress: () => PlaylistBar(
                  playlist['title']?.toString() ?? 'Playlist',
                  playlistId: id,
                  playlistArtwork: playlist['image']?.toString(),
                  playlistData: {...playlist, 'ytid': id},
                ).showActions(context),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.topLeft,
                  onPressed: () => context.push(
                    playlist['isAlbum'] == true
                        ? NavigationPaths.albumPath(context, id)
                        : NavigationPaths.playlistPath(context, id),
                    extra: playlist,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: PlaylistCube(
                          playlist,
                          size: width,
                          borderRadius: 12,
                          showTypeLabel: false,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        playlist['title']?.toString() ?? 'Playlist',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoTheme.of(
                            context,
                          ).textTheme.textStyle.color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        playlist['subtitle']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
