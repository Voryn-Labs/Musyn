import 'package:flutter/cupertino.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/smart_library.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/widgets/content_state.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/song_tile.dart';

class SmartCollectionPage extends StatefulWidget {
  const SmartCollectionPage({super.key, required this.collectionId, this.collection});
  final String collectionId;
  final Map? collection;

  @override
  State<SmartCollectionPage> createState() => _SmartCollectionPageState();
}

class _SmartCollectionPageState extends State<SmartCollectionPage> {
  final library = SmartLibrary.instance;

  @override
  void initState() {
    super.initState();
    library.addListener(_refresh);
  }

  @override
  void dispose() {
    library.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final dark = isAppDarkMode(context);
    final songs = widget.collection == null
        ? library.songsForBuiltIn(widget.collectionId)
        : library.songsForCollection(widget.collection!);
    final title = widget.collection?['name']?.toString() ?? switch (widget.collectionId) {
      'five-star' => 'Five-star tracks',
      'forgotten' => 'Rediscover',
      'never-played' => 'Never played',
      'offline-favorites' => 'Offline favorites',
      _ => 'Smart collection',
    };
    final playlist = {'ytid': '', 'title': title, 'source': 'smart-library', 'list': songs};
    return CupertinoPageScaffold(
      backgroundColor: musynCanvas(dark),
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: songs.isEmpty ? null : CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final shuffled = library.smartShuffle(songs);
            await audioHandler.addPlaylistToQueue(
              shuffled, replace: true, startIndex: 0, resetShuffle: false,
            );
          },
          child: const Icon(CupertinoIcons.shuffle),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: songs.isEmpty
            ? const ContentState(
                icon: CupertinoIcons.music_note_list,
                title: 'Nothing here yet',
                message: 'Rate and organize tracks to build this collection.',
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 12, bottom: 120),
                itemCount: songs.length + 1,
                itemBuilder: (context, index) {
                  if (index == songs.length) return const MiniPlayerBottomSpace();
                  return SongTile(
                    key: ValueKey('smart_${library.identityFor(songs[index])}'),
                    song: songs[index],
                    onTap: () => audioHandler.playPlaylistSong(
                      playlist: playlist, songIndex: index,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
