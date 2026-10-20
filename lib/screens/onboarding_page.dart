import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/widgets/musyn_brand.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});
  final Future<void> Function() onComplete;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _page = 0;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onComplete();
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Could not save your preferences. Try again.';
        });
    }
  }

  Widget _step(
    BuildContext context, {
    required Widget visual,
    required String title,
    required String description,
    List<Widget> children = const [],
  }) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: box.maxHeight < 400 ? 72 : 132,
                child: FittedBox(child: visual),
              ),
              const SizedBox(height: 30),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MusynBrand(compact: true),
                  ),
                ),
                CupertinoButton(
                  onPressed: _saving ? null : _finish,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (page) => setState(() => _page = page),
              children: [
                _step(
                  context,
                  visual: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/branding/musyn-icon.png',
                      width: 132,
                      height: 132,
                    ),
                  ),
                  title: 'Music, in your rhythm.',
                  description:
                      'Welcome to Musyn. Start with YouTube Music, build your library, and keep your favorites close. JioSaavn is an optional source you configure yourself.',
                ),
                _step(
                  context,
                  visual: const Icon(CupertinoIcons.waveform, size: 92),
                  title: 'One player. Your sources.',
                  description:
                      'Switch providers from the player menu. Set your preferred source and download quality once in Settings.',
                  children: [
                    const SizedBox(height: 24),
                    _hint(
                      CupertinoIcons.film,
                      'Artwork that moves',
                      'On iOS 26, Musyn finds matching animated album covers through Apple’s public pages. Manage this in Appearance.',
                    ),
                    _hint(
                      CupertinoIcons.arrow_down_circle,
                      'One-tap downloads',
                      'Musyn tries another enabled source when your first choice is unavailable.',
                    ),
                    _hint(
                      CupertinoIcons.person_crop_circle,
                      'An account is optional',
                      'Connect YouTube Music in Settings when you want to sync your library.',
                    ),
                  ],
                ),
                _step(
                  context,
                  visual: const Icon(CupertinoIcons.lock, size: 92),
                  title: 'Bring your own source.',
                  description:
                      'YouTube Music is ready without keys. To enable JioSaavn, add your own media URL key in Settings → JioSaavn.',
                  children: [
                    const SizedBox(height: 20),
                    _hint(
                      CupertinoIcons.lock,
                      'Stored on your device',
                      'Musyn keeps your key in iOS Keychain and excludes it from diagnostic reports.',
                    ),
                    _hint(
                      CupertinoIcons.search,
                      'A little setup help',
                      'Search “JioSaavn media URL key”. Musyn does not supply one; use only keys you are authorized to use.',
                    ),
                  ],
                ),
                _step(
                  context,
                  visual: const Icon(CupertinoIcons.headphones, size: 92),
                  title: 'Find your flow.',
                  description:
                      'A few gestures, and your music is right where you want it.',
                  children: [
                    const SizedBox(height: 24),
                    _hint(
                      CupertinoIcons.arrow_up,
                      'Open the player',
                      'Tap or pull up the mini-player. Swipe the cover to change tracks.',
                    ),
                    _hint(
                      CupertinoIcons.quote_bubble,
                      'Follow the lyrics',
                      'Open Lyrics or rotate your phone for artwork beside the words.',
                    ),
                    _hint(
                      CupertinoIcons.arrow_down_circle,
                      'Listen offline',
                      'Tap Download on the player. Your saved tracks live in Library.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Semantics(
                          label: 'Page ${i + 1} of 4',
                          selected: i == _page,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page
                                  ? CupertinoTheme.of(context).primaryColor
                                  : CupertinoColors.systemGrey3.resolveFrom(
                                      context,
                                    ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _saving
                        ? null
                        : () {
                            if (_page == 3) {
                              _finish();
                            } else {
                              if (MediaQuery.disableAnimationsOf(context)) {
                                _pages.jumpToPage(_page + 1);
                              } else {
                                _pages.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            }
                          },
                    child: _saving
                        ? const CupertinoActivityIndicator()
                        : Text(_page == 3 ? 'Start listening' : 'Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _hint(IconData icon, String title, String description) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Completion replaces the onboarding subtree, so Back cannot reopen it.
class FirstRunGate extends StatefulWidget {
  const FirstRunGate({super.key, required this.readyBuilder});
  final WidgetBuilder readyBuilder;
  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  late bool _complete =
      Hive.isBoxOpen('settings') &&
      Hive.box('settings').get('walkthroughSeen', defaultValue: false) == true;
  @override
  Widget build(BuildContext context) {
    if (_complete) return widget.readyBuilder(context);
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: buildCupertinoTheme(
        brightness: getBrightnessFromThemeMode(themeMode),
      ),
      home: OnboardingPage(
        onComplete: () async {
          await addOrUpdateData('settings', 'walkthroughSeen', true);
          if (mounted) setState(() => _complete = true);
        },
      ),
    );
  }
}
