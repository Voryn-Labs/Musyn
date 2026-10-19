import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/widgets/player_drawer.dart';

void showSongInfoDialog(BuildContext context, Map song) async {
  final ytid = song['ytid']?.toString() ?? '';
  final offlineSong = getOfflineSongByYtid(ytid);
  final isOffline = isSongAlreadyOffline(ytid);

  final title = song['title']?.toString() ?? 'Unknown Title';
  final artist = song['artist']?.toString() ?? 'Unknown Artist';

  var source = 'YouTube Music';
  var isSaavn = false;
  if (isOffline) {
    final s = offlineSong['downloadSource']?.toString().toLowerCase();
    isSaavn = s == 'saavn' || s == 'jiosaavn';
    source = isSaavn ? 'JioSaavn' : 'YouTube Music';
  } else if (song['resolvedSource'] != null) {
    isSaavn = song['resolvedSource'] == 'jiosaavn';
    source = isSaavn ? 'JioSaavn' : 'YouTube Music';
  }

  var bitrate = 'Dynamic / Adaptive';
  if (isOffline) {
    bitrate = offlineSong['audioBitrateKbps'] != null
        ? '${offlineSong['audioBitrateKbps']} kbps'
        : 'Unknown';
  } else if (song['resolvedBitrate'] != null) {
    bitrate = '${song['resolvedBitrate']} kbps';
  }

  var format = 'AAC / Opus';
  if (isOffline) {
    format = offlineSong['audioCodec']?.toString() ?? 'Unknown';
  } else if (song['resolvedFormat'] != null) {
    format = song['resolvedFormat'].toString();
  }

  var fileSize = 'Streaming';
  if (isOffline) {
    try {
      final audioPath = offlineSong['audioPath']?.toString();
      if (audioPath != null) {
        final f = File(audioPath);
        if (await f.exists()) {
          final bytes = await f.length();
          final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
          fileSize = '$mb MB';
        }
      }
    } catch (_) {}
  }

  var dateAdded = 'Unknown';
  if (isOffline && offlineSong['dateAdded'] != null) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      offlineSong['dateAdded'] is int
          ? offlineSong['dateAdded']
          : int.tryParse(offlineSong['dateAdded'].toString()) ?? 0,
    );
    dateAdded =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  if (!context.mounted) return;

  unawaited(
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.50),
      builder: (ctx) => PlayerDrawer(
        title: 'Track Details',
        subtitle: '$title · $artist',
        trailingHeader: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Done',
            style: TextStyle(
              fontFamily: MusynStyle.uiFont,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MusynStyle.appleRed,
            ),
          ),
        ),
        children: [
          PlayerDrawerRow(
            title: 'Audio Source',
            subtitle: source,
            badge: 'Compressed audio',
            icon: isSaavn
                ? CupertinoIcons.waveform
                : CupertinoIcons.play_rectangle_fill,
            iconBg: isSaavn
                ? CupertinoColors.systemGreen
                : const Color(0xFFFF0033),
          ),
          PlayerDrawerRow(
            title: 'Audio Bitrate',
            subtitle: bitrate,
            icon: CupertinoIcons.speedometer,
            iconBg: CupertinoColors.systemIndigo,
          ),
          PlayerDrawerRow(
            title: 'Audio Format',
            subtitle: format,
            icon: CupertinoIcons.music_note,
            iconBg: CupertinoColors.systemOrange,
          ),
          PlayerDrawerRow(
            title: 'Storage',
            subtitle: isOffline
                ? 'Downloaded to this device ($fileSize)'
                : 'Streaming Online',
            badge: isOffline ? 'Offline' : 'Online',
            icon: isOffline
                ? CupertinoIcons.arrow_down_circle_fill
                : CupertinoIcons.cloud,
            iconBg: isOffline
                ? CupertinoColors.systemTeal
                : CupertinoColors.systemBlue,
          ),
          if (isOffline)
            PlayerDrawerRow(
              title: 'Saved Date',
              subtitle: dateAdded,
              icon: CupertinoIcons.calendar,
              iconBg: CupertinoColors.systemPurple,
            ),
        ],
      ),
    ),
  );
}
