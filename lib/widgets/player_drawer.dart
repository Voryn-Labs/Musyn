import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';

/// Reusable BitChord bottom drawer shell (matching BitChord's PlayerDrawer.kt).
///
/// Features:
/// - 26dp top rounded corners
/// - 50% dark backdrop scrim
/// - Dark frosted acrylic material
/// - Centered grab handle pill with vertical drag-down to dismiss
/// - Standardized typography, spacing, and 16dp rounded card rows
class PlayerDrawer extends StatefulWidget {
  const PlayerDrawer({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.trailingHeader,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailingHeader;

  static const double topRadius = 26;
  static const double rowRadius = 16;

  @override
  State<PlayerDrawer> createState() => _PlayerDrawerState();
}

class _PlayerDrawerState extends State<PlayerDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dragController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  double _dragOffset = 0;

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 400.0);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > 90 || velocity > 350) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final sheetBg = isDark
        ? const Color(0xF518181A)
        : const Color(0xF5F7F7F8);
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    const secondaryColor = CupertinoColors.systemGrey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _dragOffset, 0),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PlayerDrawer.topRadius),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                width: double.infinity,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag-to-dismiss handle strip
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: _onVerticalDragUpdate,
                        onVerticalDragEnd: _onVerticalDragEnd,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 10, bottom: 8),
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 5,
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
                      // Header Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontFamily: MusynStyle.displayFont,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: titleColor,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  if (widget.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle!,
                                      style: const TextStyle(
                                        fontFamily: MusynStyle.uiFont,
                                        fontSize: 13,
                                        color: secondaryColor,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (widget.trailingHeader != null)
                              widget.trailingHeader!,
                          ],
                        ),
                      ),
                      // Children list
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.children,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// BitChord-styled row inside PlayerDrawer (16dp rounded card).
class PlayerDrawerRow extends StatelessWidget {
  const PlayerDrawerRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    this.badge,
    this.selected = false,
    this.enabled = true,
    this.loading = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final String? badge;
  final bool selected;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final cardBg = selected
        ? (isDark
            ? MusynStyle.appleRed.withValues(alpha: 0.16)
            : MusynStyle.appleRed.withValues(alpha: 0.10))
        : (isDark
            ? const Color(0x1AFFFFFF)
            : const Color(0x0A000000));
    final borderColor = selected
        ? MusynStyle.appleRed.withValues(alpha: 0.35)
        : (isDark
            ? const Color(0x14FFFFFF)
            : const Color(0x0F000000));
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    const secondaryColor = CupertinoColors.systemGrey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled && !loading ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1.0 : 0.42,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(PlayerDrawer.rowRadius),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.0 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: MusynStyle.displayFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: titleColor,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x26FFFFFF)
                                  : const Color(0x1F000000),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                fontFamily: MusynStyle.uiFont,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: secondaryColor,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: MusynStyle.uiFont,
                        fontSize: 13,
                        color: secondaryColor,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (loading)
                const CupertinoActivityIndicator()
              else if (selected)
                const Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 22,
                  color: MusynStyle.appleRed,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
