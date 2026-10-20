import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:musyn/theme/app_themes.dart';

/// Shared, scrollable player sheet. Its surface includes the home-indicator inset.
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
  static const double topRadius = 24;
  static const double rowRadius = 12;
  @override
  State<PlayerDrawer> createState() => _PlayerDrawerState();
}

class _PlayerDrawerState extends State<PlayerDrawer>
    with SingleTickerProviderStateMixin {
  late final _drag = AnimationController.unbounded(vsync: this);
  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _settle([double velocity = 0]) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _drag.value = 0;
      return;
    }
    _drag.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 380, damping: 36),
        _drag.value,
        0,
        velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isAppDarkMode(context);
    return AnimatedBuilder(
      animation: _drag,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, _drag.value), child: child),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PlayerDrawer.topRadius),
          ),
          child: ColoredBox(
            color: musynCanvas(dark),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: DefaultTextStyle(
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Close sheet',
                        button: true,
                        onTap: () => Navigator.pop(context),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (_) => _drag.stop(),
                          onVerticalDragUpdate: (d) => _drag.value =
                              (_drag.value + d.delta.dy).clamp(0, 400),
                          onVerticalDragCancel: _settle,
                          onVerticalDragEnd: (d) {
                            final velocity = d.primaryVelocity ?? 0;
                            if (_drag.value > 90 || velocity > 500) {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            } else {
                              _settle(velocity);
                            }
                          },
                          child: SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Center(
                                  child: Container(
                                    width: 36,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGrey3
                                          .resolveFrom(context),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 0,
                                  bottom: 0,
                                  child:
                                      widget.trailingHeader ??
                                      CupertinoButton(
                                        padding: const EdgeInsets.all(8),
                                        onPressed: () => Navigator.pop(context),
                                        child: const Icon(
                                          CupertinoIcons.xmark_circle_fill,
                                          color: CupertinoColors.systemGrey,
                                          size: 24,
                                          semanticLabel: 'Close sheet',
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (widget.subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.subtitle!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: CupertinoColors.secondaryLabel
                                            .resolveFrom(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
  final String title, subtitle;
  final IconData icon;
  final Color iconBg;
  final String? badge;
  final bool selected, enabled, loading;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final dark = isAppDarkMode(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled && !loading,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: enabled && !loading ? onTap : null,
          child: Opacity(
            opacity: enabled || loading ? 1 : .5,
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: musynElevatedSurface(dark),
                borderRadius: BorderRadius.circular(PlayerDrawer.rowRadius),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 19, color: CupertinoColors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (loading)
                    const CupertinoActivityIndicator()
                  else if (selected)
                    Icon(
                      CupertinoIcons.checkmark,
                      size: 20,
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
