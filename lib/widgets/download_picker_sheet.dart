import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/source_resolver.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/mediaitem.dart';
import 'package:musyn/widgets/song_artwork.dart';

class DownloadPickerSheet extends StatefulWidget {
  const DownloadPickerSheet({
    required this.song,
    required this.onDownload,
    super.key,
  });

  final Map song;
  final void Function(String source, String quality) onDownload;

  @override
  State<DownloadPickerSheet> createState() => _DownloadPickerSheetState();
}

class _DownloadPickerSheetState extends State<DownloadPickerSheet> {
  late String _selectedSource = switch (downloadSource.value) {
    'saavn' || 'jiosaavn' => 'saavn',
    'youtube' => 'youtube',
    _ =>
      widget.song['resolvedSource'] == 'youtube' || !jiosaavnEnabled.value
          ? 'youtube'
          : 'saavn',
  };
  late String _selectedQuality = downloadQuality.value;

  bool _isCheckingSaavn = true;
  bool _availabilityUnknown = false;
  bool _isSaavnAvailable = true;

  @override
  void initState() {
    super.initState();
    _checkSaavnAvailability();
  }

  Future<void> _checkSaavnAvailability() async {
    try {
      if (!jiosaavnEnabled.value) {
        if (mounted) {
          setState(() {
            _isSaavnAvailable = false;
            _isCheckingSaavn = false;
            _selectedSource = 'youtube';
            _selectedQuality = '160';
          });
        }
        return;
      }

      final match = await SourceResolver()
          .resolveAudioSource(widget.song)
          .timeout(const Duration(seconds: 4));

      if (mounted) {
        setState(() {
          _isSaavnAvailable = match != null && match['url'] != null;
          _isCheckingSaavn = false;
          if (!_isSaavnAvailable && _selectedSource == 'saavn') {
            _selectedSource = 'youtube';
            if (_selectedQuality == '320') _selectedQuality = '160';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingSaavn = false;
          _availabilityUnknown = true;
          _isSaavnAvailable = true;
        });
      }
    }
  }

  List<String> get _availableBitrates =>
      _selectedSource == 'saavn' ? ['160', '320'] : ['128', '160'];

  @override
  Widget build(BuildContext context) {
    final title = widget.song['title']?.toString() ?? 'Track';
    final artist = widget.song['artist']?.toString() ?? '';
    final isDark = isAppDarkMode(context);
    final cardBg = isDark ? const Color(0x26FFFFFF) : const Color(0x0F000000);
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    const secondaryTextColor = CupertinoColors.systemGrey;

    // Sanitize quality for current source
    if (!_availableBitrates.contains(_selectedQuality)) {
      _selectedQuality = _availableBitrates.last;
    }

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SongArtworkWidget(
                        metadata: mapToMediaItem(widget.song),
                        size: 58,
                        errorWidgetIconSize: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: MusynStyle.displayFont,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.3,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            artist.isEmpty ? 'Musyn' : artist,
                            style: const TextStyle(
                              fontFamily: MusynStyle.uiFont,
                              fontSize: 13,
                              color: secondaryTextColor,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'AUDIO PROVIDER',
                  style: TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                    letterSpacing: 0.6,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSourceOption(
                  value: 'saavn',
                  title: 'JioSaavn',
                  badge: '320 kbps',
                  subtitle: !jiosaavnEnabled.value
                      ? 'Enable JioSaavn in Settings to use this source'
                      : _isCheckingSaavn
                      ? 'Checking availability...'
                      : (_availabilityUnknown
                            ? 'Availability checked when downloading'
                            : _isSaavnAvailable
                            ? 'AAC · up to 320 kbps'
                            : 'Unavailable on JioSaavn for this track'),
                  icon: CupertinoIcons.waveform,
                  iconBg: CupertinoColors.systemGreen,
                  isEnabled: !_isCheckingSaavn && _isSaavnAvailable,
                  isDark: isDark,
                  cardBg: cardBg,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                _buildSourceOption(
                  value: 'youtube',
                  title: 'YouTube Music',
                  badge: '160k AAC',
                  subtitle: 'AAC · best available stream',
                  icon: CupertinoIcons.play_rectangle_fill,
                  iconBg: const Color(0xFFFF0033),
                  isEnabled: true,
                  isDark: isDark,
                  cardBg: cardBg,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'AUDIO QUALITY',
                      style: TextStyle(
                        fontFamily: MusynStyle.uiFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                        letterSpacing: 0.6,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: MusynStyle.appleRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Up to $_selectedQuality kbps',
                        style: const TextStyle(
                          fontFamily: MusynStyle.uiFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MusynStyle.appleRed,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<String>(
                    groupValue: _selectedQuality,
                    children: {
                      for (final quality in _availableBitrates)
                        quality: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '$quality kbps',
                            style: const TextStyle(
                              fontFamily: MusynStyle.uiFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    },
                    onValueChanged: (quality) {
                      if (quality == null) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedQuality = quality);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Downloads are saved to your offline library for instant playback without an active connection.',
                  style: TextStyle(
                    fontFamily: MusynStyle.uiFont,
                    fontSize: 12,
                    color: secondaryTextColor,
                    height: 1.35,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: MusynStyle.appleRed,
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      widget.onDownload(_selectedSource, _selectedQuality);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_down_circle_fill,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Download Track',
                          style: TextStyle(
                            fontFamily: MusynStyle.uiFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required String value,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color iconBg,
    required bool isEnabled,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final selected = _selectedSource == value;

    return GestureDetector(
      onTap: isEnabled
          ? () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedSource = value;
                if (value == 'youtube' && _selectedQuality == '320') {
                  _selectedQuality = '160';
                }
              });
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.42,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? MusynStyle.appleRed.withValues(alpha: 0.12)
                : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? MusynStyle.appleRed
                  : (isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000)),
              width: selected ? 1.5 : 0.5,
            ),
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
                  child: Icon(icon, color: CupertinoColors.white, size: 19),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: MusynStyle.displayFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: selected ? MusynStyle.appleRed : textColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (isEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0x26FFFFFF)
                                  : const Color(0x1F000000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontFamily: MusynStyle.uiFont,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: MusynStyle.uiFont,
                        fontSize: 12,
                        color: secondaryTextColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                color: selected ? MusynStyle.appleRed : secondaryTextColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showDownloadPicker(
  BuildContext context,
  Map song,
  void Function(String source, String quality) onDownload,
) {
  final isDark = isAppDarkMode(context);
  final sheetBg = isDark
      ? const Color(0xE61C1C1E)
      : const Color(0xE6F2F2F7);

  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x14000000),
                width: 0.5,
              ),
            ),
          ),
          child: DownloadPickerSheet(song: song, onDownload: onDownload),
        ),
      ),
    ),
  );
}
