import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/constants/version.dart';
import 'package:musyn/screens/legal_page.dart';
import 'package:musyn/screens/onboarding_page.dart';
import 'package:musyn/screens/provider_access_page.dart';
import 'package:musyn/screens/youtube_auth_webview.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/discovery_state.dart';
import 'package:musyn/services/lock_screen_lyrics.dart';
import 'package:musyn/services/motion_artwork.dart';
import 'package:musyn/services/provider_access.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/services/youtube_music_sync_service.dart';
import 'package:musyn/services/ytdlp_client_sync_service.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/widgets/musyn_brand.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Listenable get _changes => Listenable.merge([
    ProviderAccess.instance,
    MotionArtwork.instance,
    ios26Design,
    motionArtworkEnabled,
    lockScreenLyricsEnabled,
    lockScreenArtworkLyricsEnabled,
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
    ytAutoSyncLikes,
    ytAutoSyncPlaylists,
    ytReportHistory,
    YouTubeAuthService().isSignedIn,
    YouTubeAuthService().userName,
    YouTubeMusicSyncService().isSyncing,
    YouTubeMusicSyncService().syncError,
    YouTubeMusicSyncService().pendingLikes,
  ]);

  @override
  Widget build(BuildContext context) => _page(
    context,
    'Settings',
    () => [
      _section(context, 'Your music', [
        _row(
          context,
          'YouTube Music',
          value: YouTubeAuthService().isSignedIn.value
              ? 'Connected'
              : 'Connect',
          onTap: () =>
              _open(context, 'YouTube Music', () => _accountRows(context)),
        ),
      ]),
      _section(context, 'Sources', [
        _row(
          context,
          'JioSaavn',
          value: ProviderAccess.instance.configured
              ? 'Configured'
              : 'Add your key',
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const ProviderAccessPage()),
          ),
        ),
      ]),
      _section(context, 'Music', [
        _row(
          context,
          'Playback',
          onTap: () => _open(context, 'Playback', () => _playbackRows(context)),
        ),
        _row(
          context,
          'Downloads',
          onTap: () =>
              _open(context, 'Downloads', () => _downloadRows(context)),
        ),
        _row(
          context,
          'Appearance',
          value: [
            'System',
            'Light',
            'Dark',
          ][themeModeSetting.value.clamp(0, 2)],
          onTap: () =>
              _open(context, 'Appearance', () => _appearanceRows(context)),
        ),
      ]),
      _section(context, 'Help', [
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
          'Storage & diagnostics',
          onTap: () => _open(
            context,
            'Storage & diagnostics',
            () => _supportRows(context),
          ),
        ),
      ]),
      _section(context, 'About Musyn', [
        _row(
          context,
          'Privacy',
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) =>
                  const LegalPage(title: 'Privacy', sections: privacySections),
            ),
          ),
        ),
        _row(
          context,
          'Terms of use',
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => const LegalPage(
                title: 'Terms of use',
                sections: termsSections,
              ),
            ),
          ),
        ),
        _row(
          context,
          'Report an issue',
          onTap: () => context.push('/settings/logs'),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          children: [
            const MusynBrand(compact: true),
            const SizedBox(height: 10),
            Text(
              'Version $appVersion',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _page(
    BuildContext context,
    String title,
    List<Widget> Function() sections,
  ) => AnimatedBuilder(
    animation: _changes,
    builder: (context, _) => CupertinoPageScaffold(
      backgroundColor: musynCanvas(isAppDarkMode(context)),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            border: null,
            leading: Navigator.canPop(context)
                ? CupertinoNavigationBarBackButton(
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 24, bottom: 32),
            sliver: SliverList.list(children: sections()),
          ),
        ],
      ),
    ),
  );

  void _open(
    BuildContext context,
    String title,
    List<Widget> Function() sections,
  ) => Navigator.push(
    context,
    CupertinoPageRoute(builder: (page) => _page(page, title, sections)),
  );

  List<Widget> _appearanceRows(BuildContext context) => [
    _section(
      context,
      'iOS 26',
      [
        CupertinoListTile.notched(
          title: const Text('Glass navigation'),
          trailing: CupertinoSwitch(
            value: ios26Design.value,
            onChanged: !MotionArtwork.instance.supported
                ? null
                : (value) {
                    ios26Design.value = value;
                    unawaited(
                      addOrUpdateData('settings', 'ios26Design', value),
                    );
                  },
          ),
        ),
        CupertinoListTile.notched(
          title: const Text('Automatic artwork'),
          trailing: CupertinoSwitch(
            value: motionArtworkEnabled.value,
            onChanged: !MotionArtwork.instance.supported
                ? null
                : (value) {
                    motionArtworkEnabled.value = value;
                    unawaited(
                      addOrUpdateData('settings', 'motionArtwork', value),
                    );
                  },
          ),
        ),
      ],
      footer: MotionArtwork.instance.supported
          ? 'Glass applies to navigation. Automatic artwork matches the track to Apple’s public album pages and caches an available animated cover. No import or account is needed. Tracks without a confident match keep still covers. Network, power, accessibility and iOS lock-screen limits apply.'
          : 'Requires iOS 26 or later. Your standard player remains available on earlier versions.',
    ),
    _section(
      context,
      'Display',
      [
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
      ],
      footer:
          'System follows your iPhone’s appearance. Pure black uses a black canvas in dark mode.',
    ),
    _section(
      context,
      'Lock screen',
      [
        _toggle(
          context,
          'Lyrics in artist line',
          lockScreenLyricsEnabled,
          'lockScreenLyrics',
        ),
        if (MotionArtwork.instance.supported)
          _toggle(
            context,
            'Lyrics in artwork',
            lockScreenArtworkLyricsEnabled,
            'lockScreenArtworkLyrics',
          ),
      ],
      footer:
          'Show timed lyrics in the artist line, artwork, or both. Artwork lyrics require iOS 26; tap the lock-screen artwork to expand it. iOS controls expansion and background updates. Songs without timed lyrics keep their normal metadata.',
    ),
  ];

  List<Widget> _playbackRows(BuildContext context) => [
    _section(context, 'Sources', [
      _row(
        context,
        'Default source',
        value: _sourceLabel(preferredSource.value),
        onTap: () => _selectProvider(context, preferredSource.value),
      ),
      _row(
        context,
        'JioSaavn',
        value: ProviderAccess.instance.configured
            ? 'Configured'
            : 'Add your key',
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const ProviderAccessPage()),
        ),
      ),
    ]),
    _section(context, 'Audio quality', [
      _row(
        context,
        'YouTube quality',
        value: {
          'high': 'Highest available',
          'medium': 'Balanced',
          'low': 'Data saver',
        }[audioQualitySetting.value],
        onTap: () =>
            _selectQuality(context, audioQualitySetting, 'audioQuality', const {
              'high': 'Highest available',
              'medium': 'Balanced',
              'low': 'Data saver',
            }),
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
    ]),
    _section(context, 'Listening', [
      _toggle(
        context,
        'Autoplay',
        playNextSongAutomatically,
        'playNextSongAutomatically',
      ),
      _toggle(context, 'Offline mode', offlineMode, 'offlineMode'),
    ]),
  ];

  List<Widget> _downloadRows(BuildContext context) => [
    _section(
      context,
      'Save music',
      [
        _row(
          context,
          'Download source',
          value: _sourceLabel(downloadSource.value),
          onTap: () =>
              _selectQuality(context, downloadSource, 'downloadSource', {
                'best': 'Automatic',
                if (jiosaavnAvailable) 'saavn': 'JioSaavn',
                'youtube': 'YouTube Music',
              }),
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
          'Download starts with one tap on the player. If your preferred source is unavailable, Musyn tries the other enabled source.',
    ),
  ];

  List<Widget> _accountRows(BuildContext context) {
    final service = YouTubeMusicSyncService();
    if (!YouTubeAuthService().isSignedIn.value)
      return [
        _section(
          context,
          'Your library',
          [
            _row(
              context,
              'Connect YouTube Music',
              onTap: () => _account(context),
            ),
          ],
          footer:
              'Bring your liked music and playlists into Musyn. Search, charts and playback work without an account.',
        ),
      ];
    return [
      _section(
        context,
        YouTubeAuthService().userName.value ?? 'Connected account',
        [
          _row(
            context,
            service.isSyncing.value ? 'Syncing library…' : 'Sync library',
            value: service.pendingLikes.value > 0
                ? '${service.pendingLikes.value} pending'
                : null,
            onTap: service.isSyncing.value
                ? null
                : () async {
                    final ok = await service.fullSync();
                    if (context.mounted)
                      showToast(
                        context,
                        ok
                            ? 'YouTube library synced'
                            : service.syncError.value ??
                                  'Library could not sync. Retry.',
                      );
                  },
          ),
        ],
        footer:
            service.syncError.value ??
            'Your local favorites stay saved if YouTube is unavailable.',
      ),
      _section(
        context,
        'Sync preferences',
        [
          _toggle(
            context,
            'Sync favorites',
            ytAutoSyncLikes,
            'ytAutoSyncLikes',
            onChanged: () {
              if (ytAutoSyncLikes.value) unawaited(service.fullSync());
            },
          ),
          _toggle(
            context,
            'Sync playlists',
            ytAutoSyncPlaylists,
            'ytAutoSyncPlaylists',
            onChanged: () {
              if (ytAutoSyncPlaylists.value) unawaited(service.fullSync());
            },
          ),
          _toggle(
            context,
            'Share listening history',
            ytReportHistory,
            'ytReportHistory',
          ),
        ],
        footer:
            'Favorites sync in both directions. Listening history is reported only while connected and enabled.',
      ),
      _section(context, 'Connection', [
        _row(context, 'Sign Out', onTap: () => _account(context)),
      ]),
    ];
  }

  List<Widget> _supportRows(BuildContext context) => [
    _section(context, 'Playback', [
      _row(
        context,
        'Repair YouTube playback',
        onTap: () => _syncYoutubeClient(context),
      ),
    ]),
    _section(context, 'Storage', [
      _row(
        context,
        'Clear Audio Cache',
        onTap: () async {
          final cleared = await clearAllCache();
          if (cleared) {
            if (isAudioHandlerInitialized) audioHandler.clearPreparedStreams();
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
        'Clear Artwork Cache',
        onTap: () async {
          try {
            await MotionArtwork.instance.clearCache();
            if (context.mounted) showToast(context, 'Artwork cache cleared');
          } catch (_) {
            if (context.mounted)
              showToast(
                context,
                'Artwork cache could not be cleared. Try again.',
              );
          }
        },
      ),
      _row(
        context,
        'Clear History & Recents',
        onTap: () async {
          await deleteData('user', 'searchHistory');
          await deleteData('user', 'recentlyPlayedSongs');
          userRecentlyPlayed.value = [];
          searchHistoryNotifier.value = [];
          if (context.mounted)
            showToast(context, 'Search & recent history cleared');
        },
      ),
    ]),
    _section(context, 'Support', [
      _row(
        context,
        'Diagnostic Logs',
        onTap: () => context.push('/settings/logs'),
      ),
    ]),
  ];

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
    backgroundColor: musynCanvas(isAppDarkMode(context)),
    decoration: BoxDecoration(
      color: musynElevatedSurface(isAppDarkMode(context)),
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    children: rows,
  );

  Widget _row(
    BuildContext context,
    String title, {
    String? value,
    VoidCallback? onTap,
  }) {
    final largeText = MediaQuery.textScalerOf(context).scale(17) > 22;
    final icon = <String, IconData>{
      'YouTube Music': CupertinoIcons.play_rectangle,
      'JioSaavn': CupertinoIcons.waveform,
      'Playback': CupertinoIcons.play_circle,
      'Downloads': CupertinoIcons.arrow_down_circle,
      'Appearance': CupertinoIcons.paintbrush,
      'Walkthrough': CupertinoIcons.hand_draw,
      'Storage & diagnostics': CupertinoIcons.archivebox,
      'Privacy': CupertinoIcons.lock_shield,
      'Terms of use': CupertinoIcons.doc_text,
      'Report an issue': CupertinoIcons.bubble_left_bubble_right,
    }[title];
    return CupertinoListTile.notched(
      leading: icon == null
          ? null
          : Icon(
              icon,
              size: 21,
              color: CupertinoTheme.of(context).primaryColor,
            ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: largeText && value != null ? Text(value, maxLines: 2) : null,
      additionalInfo: value == null || largeText
          ? null
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .43,
              ),
              child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
      trailing: onTap == null ? null : const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }

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
            for (final entry in {
              'auto': 'Automatic',
              'youtube': 'YouTube Music',
              if (jiosaavnAvailable) 'jiosaavn': 'JioSaavn',
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
