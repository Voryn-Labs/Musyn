import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/constants/version.dart';
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
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/widgets/mini_player_bottom_space.dart';
import 'package:musyn/widgets/player_drawer.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: usePureBlackColor,
      builder: (context, _, __) {
        final isDark = isAppDarkMode(context);
        final navBarColor = isDark
            ? const Color(0xB3121214)
            : const Color(0xB3FFFFFF);
        final scaffoldBg = musynCanvas(isDark);

        return CupertinoPageScaffold(
          backgroundColor: scaffoldBg,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverNavigationBar(
                leading: Navigator.canPop(context)
                    ? CupertinoNavigationBarBackButton(
                        color: CupertinoTheme.of(context).primaryColor,
                        onPressed: () => Navigator.maybePop(context),
                      )
                    : null,
                largeTitle: const Text(
                  'Settings',
                  style: TextStyle(
                    fontFamily: MusynStyle.displayFont,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                backgroundColor: navBarColor,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? const Color(0x26FFFFFF)
                        : const Color(0x1F000000),
                    width: 0.5,
                  ),
                ),
                trailing: Navigator.canPop(context)
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.maybePop(context),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontFamily: MusynStyle.uiFont,
                            fontWeight: FontWeight.w700,
                            color: CupertinoTheme.of(context).primaryColor,
                          ),
                        ),
                      )
                    : null,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThemeSelector(context, isDark),
                      const SizedBox(height: 20),
                      _buildYouTubeAccountCard(context, isDark),
                      const SizedBox(height: 20),
                      _buildAudioEngineSection(context, isDark),
                      const SizedBox(height: 20),
                      _buildStorageSection(context, isDark),
                      const SizedBox(height: 20),
                      _buildAboutSection(context, isDark),
                      const SizedBox(height: 12),
                      const MiniPlayerBottomSpace(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // THEME SELECTOR CARD
  // ---------------------------------------------------------------------------
  Widget _buildThemeSelector(BuildContext context, bool isDark) {
    final cardBg = musynSheetCard(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('APPEARANCE'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              ValueListenableBuilder<int>(
                valueListenable: themeModeSetting,
                builder: (context, currentThemeIndex, _) {
                  return Row(
                    children: [
                      _buildThemeOption(
                        title: 'System',
                        icon: CupertinoIcons.device_phone_portrait,
                        isSelected: currentThemeIndex == 0,
                        onTap: () => _updateTheme(context, 0),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        title: 'Light',
                        icon: CupertinoIcons.sun_max_fill,
                        isSelected: currentThemeIndex == 1,
                        onTap: () => _updateTheme(context, 1),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        title: 'Dark',
                        icon: CupertinoIcons.moon_fill,
                        isSelected: currentThemeIndex == 2,
                        onTap: () => _updateTheme(context, 2),
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),
              if (isDark) ...[
                const SizedBox(height: 12),
                Container(height: 0.5, color: const Color(0x26FFFFFF)),
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: usePureBlackColor,
                  builder: (context, pureBlack, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(
                          CupertinoIcons.circle_fill,
                          color: CupertinoColors.systemGrey,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Pure OLED Black',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoSwitch(
                          value: pureBlack,
                          activeTrackColor: MusynStyle.appleRed,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            usePureBlackColor.value = val;
                            unawaited(
                              addOrUpdateData(
                                'settings',
                                'usePureBlackColor',
                                val,
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final buttonBg = isSelected
        ? MusynStyle.appleRed
        : musynSecondarySurface(isDark);
    final textColor = isSelected
        ? CupertinoColors.white
        : (isDark ? CupertinoColors.white : CupertinoColors.black);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: buttonBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: MusynStyle.uiFont,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateTheme(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    themeModeSetting.value = index;
    syncThemeFromSettings();
    unawaited(addOrUpdateData('settings', 'themeIndex', index));
  }

  // ---------------------------------------------------------------------------
  // YOUTUBE MUSIC ACCOUNT SECTION
  // ---------------------------------------------------------------------------
  Widget _buildYouTubeAccountCard(BuildContext context, bool isDark) {
    final cardBg = musynSheetCard(isDark);

    return ValueListenableBuilder<bool>(
      valueListenable: YouTubeAuthService().isSignedIn,
      builder: (context, isSignedIn, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('YOUTUBE MUSIC SYNC'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0x1FFFFFFF)
                      : const Color(0x0A000000),
                  width: 0.8,
                ),
              ),
              child: isSignedIn
                  ? _buildSignedInContent(context, isDark)
                  : _buildSignedOutContent(context, isDark),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSignedOutContent(BuildContext context, bool isDark) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFF0033),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            CupertinoIcons.play_rectangle_fill,
            color: CupertinoColors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect YouTube Music',
                style: TextStyle(
                  fontFamily: MusynStyle.displayFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Sync your liked tracks, playlists & mixes',
                style: TextStyle(
                  fontFamily: MusynStyle.uiFont,
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFFFF0033),
          borderRadius: BorderRadius.circular(20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => const YouTubeAuthWebView(),
              ),
            );
          },
          child: const Text(
            'Sign In',
            style: TextStyle(
              fontFamily: MusynStyle.uiFont,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedInContent(BuildContext context, bool isDark) {
    final name = YouTubeAuthService().userName.value ?? 'YouTube User';
    final email = YouTubeAuthService().userEmail.value ?? 'Connected';

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'Y',
                  style: const TextStyle(
                    fontFamily: MusynStyle.displayFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: MusynStyle.displayFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  fontFamily: MusynStyle.uiFont,
                  color: CupertinoColors.destructiveRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                YouTubeAuthService().signOut();
                showToast(context, 'Signed out of YouTube Music');
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 0.5,
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            unawaited(YouTubeMusicSyncService().fullSync());
            showToast(context, 'Syncing YouTube Music library...');
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.arrow_2_circlepath,
                    color: CupertinoColors.systemGreen,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Sync Library Now',
                    style: TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGreen,
                    ),
                  ),
                ],
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // AUDIO & PLAYBACK ENGINE
  // ---------------------------------------------------------------------------
  Widget _buildAudioEngineSection(BuildContext context, bool isDark) {
    final cardBg = musynSheetCard(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PLAYBACK & AUDIO QUALITY'),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: preferredSource,
                builder: (context, source, _) {
                  String label;
                  if (source == 'saavn' || source == 'jiosaavn') {
                    label = 'JioSaavn';
                  } else if (source == 'youtube') {
                    label = 'YouTube Music';
                  } else {
                    label = 'Auto';
                  }
                  return _buildSettingRow(
                    icon: CupertinoIcons.music_note_2,
                    iconBg: CupertinoColors.systemIndigo,
                    title: 'Default Audio Provider',
                    subtitle:
                        'Applies to upcoming tracks. Switch the current track in the player.',
                    trailingText: label,
                    onTap: () => _selectProvider(context, source),
                    isDark: isDark,
                  );
                },
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<String>(
                valueListenable: audioQualitySetting,
                builder: (context, value, _) => _buildSettingRow(
                  icon: CupertinoIcons.waveform,
                  iconBg: const Color(0xFFFF0033),
                  title: 'YouTube streaming quality',
                  subtitle:
                      'Applies to upcoming tracks. Available quality depends on the track.',
                  trailingText:
                      const {
                        'high': 'Highest',
                        'medium': 'Balanced',
                        'low': 'Data saver',
                      }[value] ??
                      'Highest',
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
                  isDark: isDark,
                ),
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<String>(
                valueListenable: jiosaavnQuality,
                builder: (context, value, _) => _buildSettingRow(
                  icon: CupertinoIcons.music_note,
                  iconBg: CupertinoColors.systemGreen,
                  title: 'JioSaavn streaming quality',
                  subtitle: 'AAC audio for upcoming tracks.',
                  trailingText: '$value kbps',
                  onTap: () => _selectQuality(
                    context,
                    jiosaavnQuality,
                    'jiosaavnQuality',
                    const {'160': '160 kbps', '320': '320 kbps'},
                  ),
                  isDark: isDark,
                ),
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<int>(
                valueListenable: YtdlpClientSyncService.instance.revision,
                builder: (context, _, __) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: YtdlpClientSyncService.instance.syncing,
                    builder: (context, syncing, __) {
                      final service = YtdlpClientSyncService.instance;
                      return _buildSettingRow(
                        icon: CupertinoIcons.cloud_download,
                        iconBg: CupertinoColors.systemTeal,
                        title: 'Repair YouTube playback',
                        subtitle: syncing
                            ? 'Updating playback settings…'
                            : _clientSyncSubtitle(service.lastSyncedAt.value),
                        trailingText: syncing ? 'Updating' : 'Refresh',
                        onTap: syncing
                            ? null
                            : () => unawaited(_syncYoutubeClient(context)),
                        isDark: isDark,
                      );
                    },
                  );
                },
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<bool>(
                valueListenable: jiosaavnEnabled,
                builder: (context, enabled, _) {
                  return _buildSwitchRow(
                    icon: CupertinoIcons.waveform,
                    iconBg: CupertinoColors.systemGreen,
                    title: 'JioSaavn AAC · up to 320 kbps',
                    subtitle: 'Allow matching and playback from JioSaavn.',
                    value: enabled,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      jiosaavnEnabled.value = val;
                      unawaited(
                        addOrUpdateData('settings', 'jiosaavnEnabled', val),
                      );
                    },
                    isDark: isDark,
                  );
                },
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<bool>(
                valueListenable: playNextSongAutomatically,
                builder: (context, autoPlay, _) {
                  return _buildSwitchRow(
                    icon: CupertinoIcons.infinite,
                    iconBg: CupertinoColors.systemPurple,
                    title: 'Infinite Recommendations',
                    subtitle: 'Auto-play similar music when queue ends',
                    value: autoPlay,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      playNextSongAutomatically.value = val;
                      unawaited(
                        addOrUpdateData(
                          'settings',
                          'playNextSongAutomatically',
                          val,
                        ),
                      );
                    },
                    isDark: isDark,
                  );
                },
              ),
              _buildDivider(isDark),
              ValueListenableBuilder<bool>(
                valueListenable: offlineMode,
                builder: (context, offline, _) {
                  return _buildSwitchRow(
                    icon: CupertinoIcons.airplane,
                    iconBg: CupertinoColors.systemOrange,
                    title: 'Offline Mode Only',
                    subtitle: 'Play exclusively from downloaded local tracks',
                    value: offline,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      offlineMode.value = val;
                      unawaited(
                        addOrUpdateData('settings', 'offlineMode', val),
                      );
                    },
                    isDark: isDark,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STORAGE & CACHE
  // ---------------------------------------------------------------------------
  Widget _buildStorageSection(BuildContext context, bool isDark) {
    final cardBg = musynSheetCard(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('STORAGE & CACHE'),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              _buildSettingRow(
                icon: CupertinoIcons.trash_fill,
                iconBg: CupertinoColors.systemRed,
                title: 'Clear Audio Cache',
                subtitle:
                    'Remove temporary playback data. Downloads stay saved.',
                onTap: () async {
                  unawaited(HapticFeedback.mediumImpact());
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
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingRow(
                icon: CupertinoIcons.clock_fill,
                iconBg: CupertinoColors.systemBlue,
                title: 'Clear History & Recents',
                subtitle: 'Resets search keywords and recently played',
                onTap: () async {
                  unawaited(HapticFeedback.mediumImpact());
                  await deleteData('user', 'searchHistory');
                  await deleteData('user', 'recentlyPlayed');
                  userRecentlyPlayed.value = [];
                  searchHistoryNotifier.value = [];
                  if (context.mounted)
                    showToast(context, 'Search & recent history cleared');
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ABOUT MUSIFIED
  // ---------------------------------------------------------------------------
  Widget _buildAboutSection(BuildContext context, bool isDark) {
    final cardBg = musynSheetCard(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ABOUT MUSIFIED'),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0A000000),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              _buildSettingRow(
                icon: CupertinoIcons.info_circle_fill,
                iconBg: CupertinoColors.systemPink,
                title: 'Version',
                subtitle: 'Musyn by Voryn Labs',
                trailingText: 'v$appVersion',
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildSettingRow(
                icon: CupertinoIcons.doc_plaintext,
                iconBg: CupertinoColors.systemGrey,
                title: 'Diagnostic Logs',
                subtitle: 'Inspect live network & audio pipeline logs',
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/settings/logs');
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REUSABLE ROW BUILDERS
  // ---------------------------------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: MusynStyle.uiFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    Color? iconBg,
    required String title,
    required String subtitle,
    String? trailingText,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg ?? musynSecondarySurface(isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconBg != null
                    ? CupertinoColors.white
                    : (isDark ? CupertinoColors.white : CupertinoColors.black),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: MusynStyle.uiFont,
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingText != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Text(
                  trailingText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (onTap != null)
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    Color? iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg ?? musynSecondarySurface(isDark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconBg != null
                  ? CupertinoColors.white
                  : (isDark ? CupertinoColors.white : CupertinoColors.black),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: MusynStyle.appleRed,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _selectQuality(
    BuildContext context,
    ValueNotifier<String> setting,
    String key,
    Map<String, String> options,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.50),
      builder: (sheet) => PlayerDrawer(
        title: 'Streaming Quality',
        subtitle: 'Applies to audio stream playback',
        trailingHeader: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          onPressed: () => Navigator.pop(sheet),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: MusynStyle.uiFont,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MusynStyle.appleRed,
            ),
          ),
        ),
        children: [
          for (final entry in options.entries)
            PlayerDrawerRow(
              title: entry.value,
              subtitle: setting.value == entry.key
                  ? 'Currently selected streaming quality'
                  : 'Tap to select ${entry.value}',
              icon: CupertinoIcons.waveform,
              iconBg: setting.value == entry.key
                  ? MusynStyle.appleRed
                  : CupertinoColors.systemGrey,
              selected: setting.value == entry.key,
              onTap: () async {
                Navigator.pop(sheet);
                setting.value = entry.key;
                if (isAudioHandlerInitialized) {
                  audioHandler.clearPreparedStreams();
                }
                await addOrUpdateData('settings', key, entry.key);
                await invalidateAllSongStreamCaches();
              },
            ),
        ],
      ),
    );
  }

  void _selectProvider(BuildContext context, String current) {
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.50),
      builder: (sheet) => PlayerDrawer(
        title: 'Default Audio Provider',
        subtitle: 'Applies to upcoming tracks and auto-recommendations',
        trailingHeader: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          onPressed: () => Navigator.pop(sheet),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: MusynStyle.uiFont,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MusynStyle.appleRed,
            ),
          ),
        ),
        children: [
          for (final entry in const {
            'auto': 'Auto',
            'youtube': 'YouTube Music',
            'jiosaavn': 'JioSaavn',
          }.entries)
            PlayerDrawerRow(
              title:
                  '${current == entry.key || (current == 'saavn' && entry.key == 'jiosaavn') ? '✓ ' : ''}${entry.value}',
              subtitle: switch (entry.key) {
                'auto' => 'Dynamically picks best available source per track',
                'youtube' => 'Prioritizes YouTube Music audio stream',
                'jiosaavn' => 'Prefers JioSaavn AAC, up to 320 kbps',
                _ => '',
              },
              icon: switch (entry.key) {
                'auto' => CupertinoIcons.sparkles,
                'youtube' => CupertinoIcons.play_rectangle_fill,
                'jiosaavn' => CupertinoIcons.waveform,
                _ => CupertinoIcons.music_note,
              },
              iconBg: switch (entry.key) {
                'auto' => CupertinoColors.systemIndigo,
                'youtube' => const Color(0xFFFF0033),
                'jiosaavn' => CupertinoColors.systemGreen,
                _ => MusynStyle.appleRed,
              },
              selected:
                  current == entry.key ||
                  (current == 'saavn' && entry.key == 'jiosaavn'),
              onTap: () {
                Navigator.pop(sheet);
                preferredSource.value = entry.key;
                unawaited(
                  addOrUpdateData('settings', 'preferredSource', entry.key),
                );
                if (isAudioHandlerInitialized) {
                  audioHandler.clearPinnedSources();
                }
              },
            ),
        ],
      ),
    );
  }

  String _clientSyncSubtitle(DateTime? syncedAt) {
    if (syncedAt == null) {
      return 'Refresh connection settings if YouTube tracks fail to play';
    }
    final elapsed = DateTime.now().difference(syncedAt);
    if (elapsed.inMinutes < 1) return 'Playback settings updated just now';
    if (elapsed.inHours < 1) {
      return 'Playback settings updated ${elapsed.inMinutes}m ago';
    }
    if (elapsed.inDays < 1) {
      return 'Playback settings updated ${elapsed.inHours}h ago';
    }
    return 'Playback settings updated ${elapsed.inDays}d ago';
  }

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

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 68),
      color: isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
    );
  }
}
