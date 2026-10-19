import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/widgets/now_playing/source_picker_sheet.dart';

void main() {
  testWidgets(
    'source sheet shows pending state, blocks duplicate taps and permits retry',
    (tester) async {
      final result = Completer<String?>();
      var calls = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () => showAudioSourcePicker(
                  context,
                  const MediaItem(
                    id: 'queue-one',
                    title: 'Song',
                    extras: {
                      'ytid': 'abcdefghijk',
                      'resolvedSource': 'youtube',
                    },
                  ),
                  switchSource: (_) {
                    calls++;
                    return result.future;
                  },
                ),
                child: const Text('Choose source'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose source'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JioSaavn'));
      await tester.pump();
      expect(find.text('Switching source…'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      await tester.tap(find.text('JioSaavn'));
      expect(calls, 1);
      result.complete(null);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not switch source.'), findsOneWidget);
      expect(find.text('JioSaavn'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('JioSaavn'), findsNothing);
    },
  );
}
