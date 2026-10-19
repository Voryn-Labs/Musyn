import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';

class PlaylistActionButtons extends StatelessWidget {
  const PlaylistActionButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.isLoading = false,
  });

  final VoidCallback onPlay;
  final AsyncCallback onShuffle;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final secondaryBtnBg = musynSecondarySurface(isDark);
    final secondaryTextColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(MusynStyle.radiusPill),
              color: CupertinoTheme.of(context).primaryColor,
              onPressed: isLoading ? null : onPlay,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const CupertinoActivityIndicator(radius: 9)
                  else
                    Icon(
                      CupertinoIcons.play_fill,
                      size: 18,
                      color: isDark
                          ? CupertinoColors.black
                          : CupertinoColors.white,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'Play',
                    style: TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      color: isDark
                          ? CupertinoColors.black
                          : CupertinoColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(MusynStyle.radiusPill),
              color: secondaryBtnBg,
              onPressed: isLoading ? null : onShuffle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const CupertinoActivityIndicator(radius: 9)
                  else
                    Icon(
                      CupertinoIcons.shuffle,
                      size: 18,
                      color: secondaryTextColor,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'Shuffle',
                    style: TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
