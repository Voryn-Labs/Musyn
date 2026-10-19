import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:musyn/services/audio/audio_runtime.dart';

void showSleepTimerPicker(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: const Text('Sleep timer'),
      actions: [
        for (final minutes in [15, 30, 45, 60])
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheet);
              unawaited(audioHandler.setSleepTimer(Duration(minutes: minutes)));
            },
            child: Text('$minutes minutes'),
          ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(sheet);
            unawaited(audioHandler.setSleepTimerEndOfSong());
          },
          child: const Text('End of track'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(sheet);
            audioHandler.cancelSleepTimer();
          },
          child: const Text('Turn off timer'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheet),
        child: const Text('Cancel'),
      ),
    ),
  );
}
