import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/widgets/download_picker_sheet.dart';

void main() {
  testWidgets(
    'automatic preference produces an explicit source and selected quality',
    (tester) async {
      final previousEnabled = jiosaavnEnabled.value;
      final previousSource = downloadSource.value;
      final previousQuality = downloadQuality.value;
      addTearDown(() {
        jiosaavnEnabled.value = previousEnabled;
        downloadSource.value = previousSource;
        downloadQuality.value = previousQuality;
      });
      jiosaavnEnabled.value = false;
      downloadSource.value = 'best';
      downloadQuality.value = '320';
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selectedSource;
      String? selectedQuality;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => CupertinoButton(
                child: const Text('Open download'),
                onPressed: () => showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) => DownloadPickerSheet(
                    song: const {
                      'ytid': 'abcdefghijk',
                      'title': 'Example',
                      'artist': 'Artist',
                    },
                    onDownload: (source, quality) {
                      selectedSource = source;
                      selectedQuality = quality;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open download'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Lossless'), findsNothing);
      expect(
        find.byType(CupertinoSlidingSegmentedControl<String>),
        findsOneWidget,
      );
      await tester.tap(find.text('128 kbps'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Download Track'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(selectedSource, 'youtube');
      expect(selectedQuality, '128');
    },
  );
}
