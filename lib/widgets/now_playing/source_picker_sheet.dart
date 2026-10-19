import 'dart:async';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';

/// Apple Music / BitChord styled Cupertino action sheet for selecting
/// JioSaavn, YouTube Music, or Offline playback source.
void showAudioSourcePicker(
  BuildContext context,
  MediaItem metadata, {
  Future<String?> Function(String)? switchSource,
}) {
  final extras = metadata.extras ?? {};
  final ytid = extras['ytid']?.toString() ?? '';
  final hasDownload = hasPlayableOfflineFile(ytid);
  final resolvedSource = extras['resolvedSource'] as String?;
  final playingOffline =
      resolvedSource == 'offline' ||
      (resolvedSource == null && (extras['isOffline'] == true || hasDownload));
  final currentSource = playingOffline
      ? 'offline'
      : (resolvedSource ?? 'youtube');
  final isOffline = playingOffline;

  final scroll = ScrollController();
  String? pendingSource;
  String? sourceError;
  showCupertinoModalPopup<void>(
    context: context,
    barrierColor: CupertinoColors.black.withValues(alpha: 0.65),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, updateSheet) {
        final isDark = isAppDarkMode(ctx);
        final sheetBg = isDark
            ? const Color(0xF51C1C1E)
            : const Color(0xF5F2F2F7);
        final rowBg = isDark
            ? const Color(0x33FFFFFF)
            : const Color(0x66FFFFFF);
        final label = isDark ? CupertinoColors.white : CupertinoColors.black;
        const secondary = CupertinoColors.systemGrey;
        final separator = isDark
            ? const Color(0x1FFFFFFF)
            : const Color(0x1F000000);

        Widget row({
          required IconData icon,
          required Color iconBg,
          required String title,
          required String subtitle,
          required String badge,
          required bool selected,
          required bool enabled,
          required VoidCallback? onTap,
          bool loading = false,
        }) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled && pendingSource == null ? onTap : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.42,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(9),
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
                                  color: label,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0x26FFFFFF)
                                      : const Color(0x1F000000),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(
                                    fontFamily: MusynStyle.uiFont,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: secondary,
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
                              color: secondary,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (loading) const CupertinoActivityIndicator(),
                    if (selected && !loading)
                      const Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 22,
                        color: MusynStyle.appleRed,
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        Future<void> select(String source) async {
          if (pendingSource != null) return;
          if (currentSource == source) {
            Navigator.pop(ctx);
            return;
          }
          unawaited(HapticFeedback.selectionClick());
          updateSheet(() {
            pendingSource = source;
            sourceError = null;
          });
          String? actual;
          try {
            actual = await (switchSource ?? audioHandler.switchSource)(source);
          } catch (_) {}
          if (!ctx.mounted) return;
          if (actual == source) {
            Navigator.pop(ctx);
          } else {
            updateSheet(() {
              pendingSource = null;
              sourceError =
                  'Could not switch source. Choose a source to retry.';
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted && scroll.hasClients) {
                scroll.animateTo(
                  0,
                  duration: MediaQuery.disableAnimationsOf(ctx)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .85,
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
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
                    controller: scroll,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Center(
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Text(
                            pendingSource != null
                                ? 'Switching source…'
                                : sourceError ?? 'AUDIO STREAM PROVIDER',
                            style: TextStyle(
                              fontFamily: MusynStyle.uiFont,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sourceError != null
                                  ? CupertinoColors.destructiveRed
                                  : secondary,
                              letterSpacing: 0.6,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          decoration: BoxDecoration(
                            color: rowBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              row(
                                icon: CupertinoIcons.waveform,
                                iconBg: CupertinoColors.systemGreen,
                                title: 'JioSaavn',
                                badge: '320k Lossless',
                                loading: pendingSource == 'jiosaavn',
                                subtitle: jiosaavnEnabled.value
                                    ? 'AAC · up to 320 kbps (High Fidelity)'
                                    : 'Enable JioSaavn in Settings to use this source',
                                selected: currentSource == 'jiosaavn',
                                enabled: jiosaavnEnabled.value,
                                onTap: () => select('jiosaavn'),
                              ),
                              Container(height: 0.5, color: separator),
                              row(
                                icon: CupertinoIcons.play_rectangle_fill,
                                iconBg: const Color(0xFFFF0033),
                                title: 'YouTube Music',
                                badge: '160k AAC',
                                loading: pendingSource == 'youtube',
                                subtitle: 'AAC · Adaptive Stream',
                                selected: currentSource == 'youtube',
                                enabled: true,
                                onTap: () => select('youtube'),
                              ),
                              Container(height: 0.5, color: separator),
                              row(
                                icon: CupertinoIcons.arrow_down_circle_fill,
                                iconBg: CupertinoColors.systemBlue,
                                title: 'Downloaded',
                                badge: 'Offline',
                                loading: pendingSource == 'offline',
                                subtitle: hasDownload
                                    ? (isOffline
                                          ? 'Playing from this device'
                                          : 'Play the downloaded copy')
                                    : 'Download this track to use offline',
                                selected: isOffline,
                                enabled: hasDownload && !isOffline,
                                onTap: hasDownload
                                    ? () => select('offline')
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        Container(height: 0.5, color: separator),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: MusynStyle.uiFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: MusynStyle.appleRed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ).whenComplete(scroll.dispose);
}

bool _isPlayingOffline(Map extras) {
  final resolvedSource = extras['resolvedSource'];
  if (resolvedSource == 'offline') return true;
  if (resolvedSource == 'youtube' || resolvedSource == 'jiosaavn') return false;
  final ytid = extras['ytid']?.toString() ?? '';
  return extras['isOffline'] == true || hasPlayableOfflineFile(ytid);
}

IconData audioSourceIcon(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (_isPlayingOffline(extras)) return CupertinoIcons.device_phone_portrait;
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoIcons.waveform;
  }
  return CupertinoIcons.play_rectangle_fill;
}

Color audioSourceColor(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (_isPlayingOffline(extras)) return CupertinoColors.systemGrey;
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoColors.systemGreen;
  }
  return const Color(0xFFFF0033);
}
