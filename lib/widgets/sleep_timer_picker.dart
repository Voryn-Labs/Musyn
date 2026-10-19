import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/theme/musyn_style.dart';
import 'package:musyn/widgets/player_drawer.dart';

void showSleepTimerPicker(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    barrierColor: CupertinoColors.black.withValues(alpha: 0.50),
    builder: (sheet) => PlayerDrawer(
      title: 'Sleep Timer',
      subtitle: 'Automatically pauses playback after a set duration',
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
        for (final minutes in [15, 30, 45, 60])
          PlayerDrawerRow(
            title: '$minutes Minutes',
            subtitle: 'Pause audio in $minutes minutes',
            icon: CupertinoIcons.timer,
            iconBg: CupertinoColors.systemIndigo,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(sheet);
              unawaited(audioHandler.setSleepTimer(Duration(minutes: minutes)));
            },
          ),
        PlayerDrawerRow(
          title: 'End of Track',
          subtitle: 'Pause playback when current song finishes',
          icon: CupertinoIcons.stop_circle_fill,
          iconBg: CupertinoColors.systemPurple,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(sheet);
            unawaited(audioHandler.setSleepTimerEndOfSong());
          },
        ),
        PlayerDrawerRow(
          title: 'Turn Off Timer',
          subtitle: 'Cancel any running sleep timer',
          icon: CupertinoIcons.clear_circled_solid,
          iconBg: CupertinoColors.systemGrey,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(sheet);
            audioHandler.cancelSleepTimer();
          },
        ),
      ],
    ),
  );
}
