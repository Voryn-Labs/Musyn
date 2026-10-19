import 'package:flutter/cupertino.dart';

class MusynBrand extends StatelessWidget {
  const MusynBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 8 : 16),
        child: Image.asset(
          'assets/branding/musyn-icon.png',
          width: compact ? 30 : 64,
          height: compact ? 30 : 64,
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Musyn',
              style: TextStyle(
                fontSize: compact ? 18 : 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
            Text(
              'By Voryn Labs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
