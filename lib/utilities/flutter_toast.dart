import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:musyn/services/app_navigation_state.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';

OverlayEntry? _activeToast;
Timer? _toastTimer;

void showToast(
  BuildContext context,
  String text, {
  Duration duration = const Duration(seconds: 2),
  IconData? icon,
}) {
  _dismissToast();

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final isDark = isAppDarkMode(context);
  final top = MediaQuery.paddingOf(context).top + 10.0;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, top, 20, 0),
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 180),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xE61C1C1E)
                      : const Color(0xF21C1C1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? const Color(0x33FFFFFF)
                        : const Color(0x1F000000),
                    width: 0.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon ?? CupertinoIcons.checkmark_circle_fill,
                      size: 18,
                      color: MusynStyle.appleRed,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontFamily: MusynStyle.uiFont,
                          color: CupertinoColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeToast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(duration, _dismissToast);
}

void showToastWithButton(
  BuildContext context,
  String text,
  String buttonName,
  VoidCallback onPressedToast, {
  Duration duration = const Duration(seconds: 3),
  IconData? icon,
}) {
  _dismissToast();

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final isDark = isAppDarkMode(context);
  final top = MediaQuery.paddingOf(context).top + 10.0;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, top, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xE61C1C1E)
                  : const Color(0xF21C1C1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x1F000000),
                width: 0.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ?? CupertinoIcons.info_circle_fill,
                  size: 18,
                  color: MusynStyle.appleRed,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      color: CupertinoColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  onPressed: () {
                    _dismissToast();
                    onPressedToast();
                  },
                  child: Text(
                    buttonName,
                    style: const TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      color: MusynStyle.appleRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  _activeToast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(duration, _dismissToast);
}

void _dismissToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _activeToast?.remove();
  _activeToast = null;
}

/// Toast from services (e.g. audio handler) without a local [BuildContext].
void showAppToast(
  String text, {
  Duration duration = const Duration(seconds: 3),
  IconData icon = CupertinoIcons.exclamationmark_circle_fill,
}) {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;
  showToast(context, text, duration: duration, icon: icon);
}
