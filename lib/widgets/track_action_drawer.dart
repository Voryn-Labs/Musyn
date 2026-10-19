import 'package:flutter/cupertino.dart';
import 'package:musyn/theme/app_themes.dart';

/// BitChord's rounded track drawer: sleeve header, grabber and aligned actions.
class TrackActionDrawer extends StatelessWidget {
  const TrackActionDrawer({
    super.key,
    required this.title,
    required this.actions,
    required this.cancelButton,
  });
  final Widget title;
  final List<Widget> actions;
  final Widget cancelButton;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
      maxWidth: 560,
    ),
    decoration: BoxDecoration(
      color: musynElevatedSurface(isAppDarkMode(context)),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 300)
                  Navigator.pop(context);
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: title,
            ),
            for (final action in actions) ...[
              Container(
                height: .5,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: CupertinoColors.systemGrey.withValues(alpha: .18),
              ),
              action,
            ],
            cancelButton,
          ],
        ),
      ),
    ),
  );
}
