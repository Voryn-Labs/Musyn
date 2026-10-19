import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/app_navigation_state.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
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
  }

  @override
  void dispose() {
    offlineMode.removeListener(_offlineChanged);
    super.dispose();
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
      child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: audioHandlerReady,
                builder: (context, ready, _) => StreamBuilder<bool>(
                  initialData:
                      ready && audioHandler.mediaItem.valueOrNull != null,
                  stream: ready
                      ? audioHandler.mediaItem
                            .map((item) => item != null)
                            .distinct()
                      : null,
                  builder: (context, snapshot) {
                    final media = MediaQuery.of(context);
                    final obstruction =
                        media.padding.bottom.clamp(15.0, double.infinity) +
                        76 +
                        ((snapshot.data ?? false)
                            ? MiniPlayer.playerHeight + 8
                            : 0);
                    return MediaQuery(
                      data: media.copyWith(
                        padding: media.padding.copyWith(bottom: obstruction),
                      ),
                      child: widget.child,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      musynCanvas(dark).withValues(alpha: 0),
                      musynCanvas(dark),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 18,
                    bottom: MediaQuery.paddingOf(
                      context,
                    ).bottom.clamp(15.0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MiniPlayer(),
                          BitChordTabBar(
                            selectedIndex: widget.child.currentIndex,
                            onSelect: _select,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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

/// Four peer tabs; dragging the capsule selects the destination under the finger.
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
    final dark = isAppDarkMode(context);
    final ink = dark ? CupertinoColors.white : CupertinoColors.black;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 66,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: dark ? const Color(0xE61C1C1E) : const Color(0xEDFFFFFF),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: ink.withValues(alpha: .08), width: .5),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth / 4;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final index = (details.localPosition.dx / width)
                        .floor()
                        .clamp(0, 3);
                    if (index != selectedIndex) onSelect(index);
                  },
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        left: selectedIndex * width,
                        top: 0,
                        bottom: 0,
                        width: width,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(
                          4,
                          (index) => Expanded(
                            child: Semantics(
                              selected: index == selectedIndex,
                              button: true,
                              label: _labels[index],
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onSelect(index),
                                child: SizedBox.expand(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        index == selectedIndex
                                            ? _selectedIcons[index]
                                            : _icons[index],
                                        size: 23,
                                        color: index == selectedIndex
                                            ? ink
                                            : CupertinoColors.systemGrey,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _labels[index],
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: index == selectedIndex
                                              ? ink
                                              : CupertinoColors.systemGrey,
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
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
