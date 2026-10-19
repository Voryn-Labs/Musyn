import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/mediaitem.dart';
import 'package:musyn/widgets/song_actions_sheet.dart';
import 'package:musyn/widgets/song_artwork.dart';

/// Clean, high-performance iOS Apple-style song row.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showMore = true,
    this.onRemove,
    this.canRemove = false,
    this.isRecent = false,
  });

  final Map song;
  final VoidCallback? onTap;
  final bool showMore;
  final VoidCallback? onRemove;
  final bool canRemove;
  final bool isRecent;

  @override
  Widget build(BuildContext context) {
    final ytid = song['ytid']?.toString() ?? '';
    final title = song['title']?.toString() ?? 'Unknown Title';
    final artist = song['artist']?.toString() ?? 'Unknown Artist';

    final isDark = isAppDarkMode(context);
    const primaryDark = CupertinoColors.white;
    const primaryLight = CupertinoColors.black;
    final primaryColor = isDark ? primaryDark : primaryLight;
    const secondaryColor = CupertinoColors.systemGrey;

    return ValueListenableBuilder<String?>(
      valueListenable: audioHandler.currentPlayingYtid,
      builder: (context, playingYtid, _) {
        final isPlaying = playingYtid == ytid && ytid.isNotEmpty;

        return GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            showSongActionsSheet(
              context,
              song: song,
              canRemove: canRemove,
              onRemove: onRemove,
              isRecent: isRecent,
            );
          },
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onPressed: () {
              HapticFeedback.selectionClick();
              if (onTap != null) {
                onTap!();
              } else {
                audioHandler.playSingleSong(song);
              }
            },
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(MusynStyle.radiusSm),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SongArtworkWidget(
                          metadata: mapToMediaItem(song),
                          size: 48,
                          borderRadius: MusynStyle.radiusSm,
                        ),
                        if (isPlaying)
                          const ColoredBox(
                            color: Color(0x66000000),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.waveform,
                                color: CupertinoColors.white,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: MusynStyle.uiFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: isPlaying
                              ? MusynStyle.appleRed
                              : primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        artist,
                        style: const TextStyle(
                          fontFamily: MusynStyle.uiFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: secondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showMore)
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      showSongActionsSheet(
                        context,
                        song: song,
                        canRemove: canRemove,
                        onRemove: onRemove,
                        isRecent: isRecent,
                      );
                    },
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      size: 20,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
