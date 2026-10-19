import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/widgets/player_drawer.dart';

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
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final sheetBg = isDark
        ? const Color(0xF518181A)
        : const Color(0xF5F7F7F8);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
          maxWidth: 560,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PlayerDrawer.topRadius),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(PlayerDrawer.topRadius),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0x1AFFFFFF)
                        : const Color(0x14000000),
                    width: 0.5,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) > 300) {
                          Navigator.pop(context);
                        }
                      },
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Container(
                            width: 36,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x4DFFFFFF)
                                  : const Color(0x33000000),
                              borderRadius: BorderRadius.circular(2.5),
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
                        color: isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0x0F000000),
                      ),
                      action,
                    ],
                    Container(
                      height: .5,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      color: isDark
                          ? const Color(0x1AFFFFFF)
                          : const Color(0x0F000000),
                    ),
                    cancelButton,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
