import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/constants/version.dart';
import 'package:musyn/screens/onboarding_page.dart';
import 'package:musyn/screens/youtube_auth_webview.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/discovery_state.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/services/ytdlp_client_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/widgets/musyn_brand.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      themeModeSetting,
      usePureBlackColor,
      preferredSource,
      audioQualitySetting,
      jiosaavnQuality,
      downloadSource,
      downloadQuality,
      jiosaavnEnabled,
      offlineMode,
      playNextSongAutomatically,
      YouTubeAuthService().isSignedIn,
      YouTubeAuthService().userName,
    ]),
    builder: (context, _) => CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Settings'),
            border: null,
            leading: Navigator.canPop(context)
                ? CupertinoNavigationBarBackButton(
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: MusynBrand(),
                ),
                _section(context, 'Appearance', [
                  _row(
                    context,
                    'Theme',
                    value: [
                      'System',
                      'Light',
                      'Dark',
                    ][themeModeSetting.value.clamp(0, 2)],
                    onTap: () => _chooseTheme(context),
                  ),
                  if (isAppDarkMode(context))
                    _toggle(
                      context,
                      'Pure black',
                      usePureBlackColor,
                      'usePureBlackColor',
                      onChanged: syncThemeFromSettings,
                    ),
                ]),
                _section(context, 'Playback', [
                  _row(
                    context,
                    'Default source',
                    value: _sourceLabel(preferredSource.value),
                    onTap: () =>
                        _selectProvider(context, preferredSource.value),
                  ),
                  _row(
                    context,
                    'YouTube quality',
                    value: {
                      'high': 'Highest available',
                      'medium': 'Balanced',
                      'low': 'Data saver',
                    }[audioQualitySetting.value],
                    onTap: () => _selectQuality(
                      context,
                      audioQualitySetting,
                      'audioQuality',
                      const {
                        'high': 'Highest available',
                        'medium': 'Balanced',
                        'low': 'Data saver',
                      },
                    ),
                  ),
                  _row(
                    context,
                    'JioSaavn quality',
                    value: '${jiosaavnQuality.value} kbps',
                    onTap: () => _selectQuality(
                      context,
                      jiosaavnQuality,
                      'jiosaavnQuality',
                      const {'160': '160 kbps', '320': '320 kbps'},
                    ),
                  ),
                  _toggle(
                    context,
                    'JioSaavn',
                    jiosaavnEnabled,
                    'jiosaavnEnabled',
                  ),
                  _toggle(
                    context,
                    'Autoplay',
                    playNextSongAutomatically,
                    'playNextSongAutomatically',
                  ),
                  _toggle(context, 'Offline mode', offlineMode, 'offlineMode'),
                ]),
                _section(
                  context,
                  'Downloads',
                  [
                    _row(
                      context,
                      'Download source',
                      value: _sourceLabel(downloadSource.value),
                      onTap: () => _selectQuality(
                        context,
                        downloadSource,
                        'downloadSource',
                        const {
                          'best': 'Automatic',
                          'saavn': 'JioSaavn',
                          'youtube': 'YouTube Music',
                        },
                      ),
                    ),
                    _row(
                      context,
                      'Download quality',
                      value: '${downloadQuality.value} kbps',
                      onTap: () => _selectQuality(
                        context,
                        downloadQuality,
                        'downloadQuality',
                        const {'160': '160 kbps', '320': '320 kbps'},
                      ),
                    ),
                  ],
                  footer:
                      'If your preferred download source is unavailable, Musyn tries the other enabled source.',
                ),
                _section(
                  context,
                  'YouTube Music',
                  [
                    _row(
                      context,
                      YouTubeAuthService().isSignedIn.value
                          ? YouTubeAuthService().userName.value ??
                                'YouTube Music connected'
                          : 'Connect YouTube Music',
                      value: YouTubeAuthService().isSignedIn.value
                          ? 'Connected'
                          : 'Sign In',
                      onTap: () => _account(context),
                    ),
                    if (YouTubeAuthService().isSignedIn.value)
                      _row(
                        context,
                        'Sync library',
                        onTap: () async {
                          await YouTubeMusicSyncService().fullSync();
                          if (context.mounted)
                            showToast(context, 'YouTube library synced');
                        },
                      ),
                  ],
                  footer:
                      'Optional. Search, charts and playback work without an account.',
                ),
                _section(context, 'Support', [
                  _row(
                    context,
                    'Walkthrough',
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (page) => OnboardingPage(
                          onComplete: () async {
                            Navigator.pop(page);
                          },
                        ),
                      ),
                    ),
                  ),
                  _row(
                    context,
                    'Repair YouTube playback',
                    onTap: () => _syncYoutubeClient(context),
                  ),
                  _row(
                    context,
                    'Clear Audio Cache',
                    onTap: () async {
                      final cleared = await clearAllCache();
                      if (cleared) {
                        if (isAudioHandlerInitialized)
                          audioHandler.clearPreparedStreams();
                        await invalidateAllSongStreamCaches();
                      }
                      if (context.mounted)
                        showToast(
                          context,
                          cleared
                              ? 'Audio cache cleared'
                              : 'Cache could not be cleared. Try again.',
                        );
                    },
                  ),
                  _row(
                    context,
                    'Clear History & Recents',
                    onTap: () async {
                      await deleteData('user', 'searchHistory');
                      await deleteData('user', 'recentlyPlayed');
                      userRecentlyPlayed.value = [];
                      searchHistoryNotifier.value = [];
                      if (context.mounted)
                        showToast(context, 'Search & recent history cleared');
                    },
                  ),
                  _row(
                    context,
                    'Diagnostic Logs',
                    onTap: () => context.push('/settings/logs'),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                  child: Text(
                    'Musyn $appVersion · Voryn Labs\nMusic, in your rhythm.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  String _sourceLabel(String value) => switch (value) {
    'saavn' || 'jiosaavn' => 'JioSaavn',
    'youtube' => 'YouTube Music',
    _ => 'Automatic',
  };

  Widget _section(
    BuildContext context,
    String title,
    List<Widget> rows, {
    String? footer,
  }) => CupertinoFormSection.insetGrouped(
    header: Text(
      title,
      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
    footer: footer == null
        ? null
        : Text(
            footer,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 13,
              height: 1.4,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    children: rows,
  );

  Widget _row(
    BuildContext context,
    String title, {
    String? value,
    VoidCallback? onTap,
  }) => CupertinoListTile.notched(
    title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
    additionalInfo: value == null
        ? null
        : Flexible(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
    trailing: onTap == null ? null : const CupertinoListTileChevron(),
    onTap: onTap,
  );

  Widget _toggle(
    BuildContext context,
    String title,
    ValueNotifier<bool> value,
    String key, {
    VoidCallback? onChanged,
  }) => CupertinoListTile.notched(
    title: Text(title, maxLines: 2),
    trailing: CupertinoSwitch(
      activeTrackColor: CupertinoTheme.of(context).primaryColor,
      value: value.value,
      onChanged: (next) {
        value.value = next;
        unawaited(addOrUpdateData('settings', key, next));
        onChanged?.call();
      },
    ),
  );

  void _chooseTheme(BuildContext context) => showCupertinoModalPopup<void>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: const Text('Appearance'),
      actions: [
        for (var i = 0; i < 3; i++)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheet);
              themeModeSetting.value = i;
              syncThemeFromSettings();
              unawaited(addOrUpdateData('settings', 'themeIndex', i));
            },
            child: Text(['System', 'Light', 'Dark'][i]),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheet),
        child: const Text('Cancel'),
      ),
    ),
  );

  void _account(BuildContext context) {
    if (!YouTubeAuthService().isSignedIn.value) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const YouTubeAuthWebView()),
      );
      return;
    }
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: Text(YouTubeAuthService().userName.value ?? 'YouTube Music'),
        message: const Text(
          'This connection belongs to Musyn. Other apps and iOS account settings do not share their YouTube session.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              YouTubeAuthService().signOut();
              Navigator.pop(sheet);
            },
            child: const Text('Sign Out'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _selectQuality(
    BuildContext context,
    ValueNotifier<String> setting,
    String key,
    Map<String, String> options,
  ) => showCupertinoModalPopup<void>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: Text(
        key == 'downloadSource'
            ? 'Download source'
            : key == 'downloadQuality'
            ? 'Download quality'
            : 'Streaming Quality',
      ),
      actions: [
        for (final entry in options.entries)
          CupertinoActionSheetAction(
            isDefaultAction: setting.value == entry.key,
            onPressed: () async {
              Navigator.pop(sheet);
              setting.value = entry.key;
              final affectsPlayback = !key.startsWith('download');
              if (affectsPlayback && isAudioHandlerInitialized)
                audioHandler.clearPreparedStreams();
              await addOrUpdateData('settings', key, entry.key);
              if (affectsPlayback) await invalidateAllSongStreamCaches();
            },
            child: Text(entry.value),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheet),
        child: const Text('Cancel'),
      ),
    ),
  );

  void _selectProvider(BuildContext context, String current) =>
      showCupertinoModalPopup<void>(
        context: context,
        builder: (sheet) => CupertinoActionSheet(
          title: const Text('Default Audio Provider'),
          actions: [
            for (final entry in const {
              'auto': 'Automatic',
              'youtube': 'YouTube Music',
              'jiosaavn': 'JioSaavn',
            }.entries)
              CupertinoActionSheetAction(
                isDefaultAction: current == entry.key,
                onPressed: () {
                  Navigator.pop(sheet);
                  preferredSource.value = entry.key;
                  unawaited(
                    addOrUpdateData('settings', 'preferredSource', entry.key),
                  );
                  if (isAudioHandlerInitialized)
                    audioHandler.clearPinnedSources();
                },
                child: Text(entry.value),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheet),
            child: const Text('Cancel'),
          ),
        ),
      );

  Future<void> _syncYoutubeClient(BuildContext context) async {
    unawaited(HapticFeedback.mediumImpact());
    final result = await YtdlpClientSyncService.instance.syncFromYtdlp();
    if (result.ok) {
      await invalidateAllSongStreamCaches();
    }
    if (!context.mounted) return;
    showToast(
      context,
      result.ok
          ? 'YouTube playback settings updated'
          : 'Playback settings could not be refreshed. Try again.',
    );
  }
}
