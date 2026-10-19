import 'package:flutter/cupertino.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';

class NullArtworkWidget extends StatelessWidget {
  const NullArtworkWidget({
    super.key,
    this.icon = CupertinoIcons.music_note,
    this.size = 220,
    this.iconSize,
    this.title,
    this.borderRadius = 20,
  });

  final IconData icon;
  final double? iconSize;
  final double size;
  final String? title;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final badgeSize = size * 0.4;
    final calculatedIconSize = iconSize ?? (badgeSize * 0.5);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: musynSecondarySurface(isDark),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CupertinoTheme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.08),
                ),
                child: Icon(
                  icon,
                  size: calculatedIconSize,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              if (title != null) ...[
                SizedBox(height: size * 0.045),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.08),
                  child: Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      color: CupertinoColors.systemGrey,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
