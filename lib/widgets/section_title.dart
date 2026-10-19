import 'package:flutter/cupertino.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.primaryColor, {super.key, this.icon});
  final Color primaryColor;
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: CupertinoDynamicColor.resolve(primaryColor, context),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MusynStyle.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
