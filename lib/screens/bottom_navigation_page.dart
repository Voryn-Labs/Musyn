import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/services/audio/audio_runtime.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
import 'package:musified/widgets/mini_player.dart';

/// BitChord-inspired floating glass navigation shell for iOS.
class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({required this.child, super.key});

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  Stream<bool> _miniPlayerVisibilityStream() {
    return audioHandler.mediaItem
        .map((mediaItem) => mediaItem != null)
        .distinct();
  }

  bool? _previousOfflineMode;
  int? _previousShellIndex;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.child.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final currentIndex = widget.child.currentIndex;
        if (currentIndex != 0) {
          widget.child.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([offlineMode, usePureBlackColor]),
        builder: (context, _) {
          final isOfflineMode = offlineMode.value;
          final isDark = isAppDarkMode(context);
          if (_previousOfflineMode != null &&
              _previousOfflineMode != isOfflineMode) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _handleOfflineModeChange(isOfflineMode);
            });
          }
          _previousOfflineMode = isOfflineMode;

          final items = _getNavigationItems(isOfflineMode);
          final currentIndex = _getCurrentIndex(items, isOfflineMode);

          return CupertinoPageScaffold(
            backgroundColor: musifiedCanvas(isDark),
            child: Stack(
              children: [
                // Scrollable main content with bottom padding for floating bars
                Positioned.fill(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: audioHandlerReady,
                    builder: (context, handlerReady, _) {
                      return StreamBuilder<bool>(
                        initialData: false,
                        stream: handlerReady
                            ? _miniPlayerVisibilityStream()
                            : null,
                        builder: (context, snapshot) {
                          final mediaQuery = MediaQuery.of(context);
                          final isMiniPlayerVisible = snapshot.data ?? false;
                          final safeBottom = mediaQuery.padding.bottom;
                          // 62 (nav bar) + 12 (spacing) + safeBottom + miniPlayerHeight
                          final bottomPadding = isMiniPlayerVisible
                              ? safeBottom + 74 + MiniPlayer.playerHeight
                              : safeBottom + 74;

                          return MediaQuery(
                            data: mediaQuery.copyWith(
                              padding: mediaQuery.padding.copyWith(
                                bottom: bottomPadding,
                              ),
                            ),
                            child: widget.child,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Floating MiniPlayer + Floating Glass Nav Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MiniPlayer(),
                          _FloatingGlassTabBar(
                            items: items,
                            selectedIndex: currentIndex,
                            onTap: (index) => _onTabTapped(index, items),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_NavigationItem> _getNavigationItems(bool isOfflineMode) {
    final items = <_NavigationItem>[
      _NavigationItem(
        icon: CupertinoIcons.house,
        selectedIcon: CupertinoIcons.house_fill,
        label: context.l10n.home,
        shellIndex: 0,
      ),
    ];

    if (!isOfflineMode) {
      items.add(
        _NavigationItem(
          icon: CupertinoIcons.search,
          selectedIcon: CupertinoIcons.search,
          label: context.l10n.search,
          shellIndex: 1,
        ),
      );
    }

    items.addAll([
      _NavigationItem(
        icon: CupertinoIcons.music_albums,
        selectedIcon: CupertinoIcons.music_albums_fill,
        label: context.l10n.library,
        shellIndex: 2,
      ),
      _NavigationItem(
        icon: CupertinoIcons.gear_alt,
        selectedIcon: CupertinoIcons.gear_alt_fill,
        label: context.l10n.settings,
        shellIndex: 3,
      ),
    ]);

    return items;
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;
    GoRouter.of(context).refresh();
    final currentRoute = GoRouterState.of(context).matchedLocation;
    if (isOfflineMode && currentRoute.startsWith('/search')) {
      widget.child.goBranch(0);
    }
  }

  void _onTabTapped(int index, List<_NavigationItem> items) {
    if (index < items.length) {
      final item = items[index];
      final isReselect = _previousShellIndex == item.shellIndex;
      HapticFeedback.selectionClick();
      closeCurrentBottomSheet();

      if (isReselect) {
        widget.child.goBranch(item.shellIndex, initialLocation: true);
      } else {
        widget.child.goBranch(item.shellIndex);
      }
      _previousShellIndex = item.shellIndex;
    }
  }

  int _getCurrentIndex(List<_NavigationItem> items, bool isOfflineMode) {
    final currentShellIndex = widget.child.currentIndex;
    if (items.isEmpty) return 0;
    final matchedIndex = items.indexWhere(
      (item) => item.shellIndex == currentShellIndex,
    );
    if (matchedIndex != -1) return matchedIndex;
    if (isOfflineMode && currentShellIndex == 1) return 0;
    return 0;
  }
}

class _FloatingGlassTabBar extends StatelessWidget {
  const _FloatingGlassTabBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.isDark,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xE6141416)
        : const Color(0xF2FFFFFF);
    final border = isDark
        ? const Color(0x33FFFFFF)
        : const Color(0x1F000000);
    const activeColor = MusifiedStyle.appleRed;
    final inactiveColor = isDark
        ? MusifiedStyle.darkSecondary
        : CupertinoColors.systemGrey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
              border: Border.all(color: border, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == selectedIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(index),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0x22FFFFFF)
                                  : const Color(0x12000000))
                              : const Color(0x00000000),
                          borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              size: 22,
                              color: isSelected ? activeColor : inactiveColor,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                fontSize: 10.5,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected ? activeColor : inactiveColor,
                                decoration: TextDecoration.none,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.shellIndex,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int shellIndex;
}
