import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/app_navigation_state.dart';
import 'package:musyn/services/motion_artwork.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
import 'package:musyn/widgets/ios26_surface.dart';
import 'package:musyn/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({required this.child, super.key});
  final StatefulNavigationShell child;
  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  @override
  void initState() {
    super.initState();
    offlineMode.addListener(_offlineChanged);
    ios26Design.addListener(_designChanged);
  }

  @override
  void dispose() {
    offlineMode.removeListener(_offlineChanged);
    ios26Design.removeListener(_designChanged);
    super.dispose();
  }

  void _designChanged() {
    if (mounted) setState(() {});
  }

  void _offlineChanged() {
    if (!mounted) return;
    GoRouter.of(context).refresh();
    setState(() {});
  }

  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(HapticFeedback.selectionClick());
    closeCurrentBottomSheet();
    if (index == 3) searchTabActivation.value++;
    widget.child.goBranch(
      index,
      initialLocation: index == widget.child.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isAppDarkMode(context);
    final scaffold = CupertinoPageScaffold(
      backgroundColor: musynCanvas(dark),
      child: Column(
        children: [
          Expanded(child: widget.child),
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      ios26Design.value ? 12 : 0,
                      0,
                      ios26Design.value ? 12 : 0,
                      4,
                    ),
                    child: Ios26Surface(
                      radius: 28,
                      child: BitChordTabBar(
                        selectedIndex: widget.child.currentIndex,
                        onSelect: _select,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return scaffold;
    }
    return PopScope(
      canPop: widget.child.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.child.goBranch(0);
      },
      child: scaffold,
    );
  }
}

/// Four peer tabs; dragging selects the destination under the finger.
class BitChordTabBar extends StatelessWidget {
  const BitChordTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  static const _labels = ['Home', 'Explore', 'Library', 'Search'];
  static const _icons = [
    CupertinoIcons.house,
    CupertinoIcons.compass,
    CupertinoIcons.music_albums,
    CupertinoIcons.search,
  ];
  static const _selectedIcons = [
    CupertinoIcons.house_fill,
    CupertinoIcons.compass_fill,
    CupertinoIcons.music_albums_fill,
    CupertinoIcons.search,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          final index = (details.localPosition.dx / (box.maxWidth / 4))
              .floor()
              .clamp(0, 3);
          if (index != selectedIndex) onSelect(index);
        },
        child: Stack(
          children: [
            if (ios26Design.value && MotionArtwork.instance.supported)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedAlign(
                    key: const ValueKey('tab-selection-motion'),
                    alignment: Alignment(
                      (-1 + selectedIndex * 2 / 3) *
                          (Directionality.of(context) == TextDirection.rtl
                              ? -1
                              : 1),
                      0,
                    ),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: .25,
                      heightFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isAppDarkMode(context)
                                ? const Color(0x20FFFFFF)
                                : const Color(0x10000000),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: CupertinoTabBar(
                currentIndex: selectedIndex,
                onTap: onSelect,
                height: 54,
                backgroundColor: ios26Design.value
                    ? CupertinoColors.transparent
                    : musynCanvas(isAppDarkMode(context)),
                activeColor: CupertinoTheme.of(context).primaryColor,
                inactiveColor: CupertinoColors.systemGrey,
                border: null,
                items: List.generate(
                  4,
                  (index) => BottomNavigationBarItem(
                    icon: Icon(_icons[index], size: 23),
                    activeIcon: Icon(_selectedIcons[index], size: 23),
                    label: _labels[index],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
