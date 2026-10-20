import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/services/source_resolver.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/utilities/mediaitem.dart';
import 'package:musyn/widgets/player_drawer.dart';
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
      widget.song['resolvedSource'] == 'youtube' || !jiosaavnAvailable
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
      if (!jiosaavnAvailable) {
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
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    const secondaryTextColor = CupertinoColors.systemGrey;

    // Sanitize quality for current source
    if (!_availableBitrates.contains(_selectedQuality)) {
      _selectedQuality = _availableBitrates.last;
    }

    return PlayerDrawer(
      title: 'Download',
      subtitle: 'Save this track for offline listening',
      children: [
        // Track Preview Header Card
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SongArtworkWidget(
                  metadata: mapToMediaItem(widget.song),
                  size: 40,
                  errorWidgetIconSize: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: MusynStyle.displayFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.3,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
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
        ),

        // Show only configured providers; avoid a large disabled setup card.
        if (jiosaavnAvailable)
          PlayerDrawerRow(
            title: 'JioSaavn',
            subtitle: !jiosaavnAvailable
                ? 'Add your media URL key in Settings → JioSaavn'
                : _isCheckingSaavn
                ? 'Checking availability...'
                : (_availabilityUnknown
                      ? 'Availability confirmed during download'
                      : _isSaavnAvailable
                      ? 'AAC · up to 320 kbps'
                      : 'Unavailable on JioSaavn for this track'),
            icon: CupertinoIcons.waveform,
            iconBg: CupertinoColors.systemGreen,
            selected: _selectedSource == 'saavn',
            enabled: !_isCheckingSaavn && _isSaavnAvailable,
            loading: _isCheckingSaavn,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedSource = 'saavn';
                _selectedQuality = '320';
              });
            },
          ),

        PlayerDrawerRow(
          title: 'YouTube Music',
          subtitle: 'AAC or Opus · best available within your limit',
          icon: CupertinoIcons.play_rectangle_fill,
          iconBg: const Color(0xFFFF0033),
          selected: _selectedSource == 'youtube',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedSource = 'youtube';
              if (_selectedQuality == '320') _selectedQuality = '160';
            });
          },
        ),

        if (!jiosaavnAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'JioSaavn can be added in Settings.',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        const SizedBox(height: 10),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Audio quality',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
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

        const SizedBox(height: 18),

        // Download Action Button
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: CupertinoTheme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}

Future<void> showDownloadPicker(
  BuildContext context,
  Map song,
  void Function(String source, String quality) onDownload,
) {
  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: CupertinoColors.black.withValues(alpha: 0.50),
    builder: (ctx) => DownloadPickerSheet(song: song, onDownload: onDownload),
  );
}
