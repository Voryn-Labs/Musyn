import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musyn/screens/onboarding_page.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musyn-onboarding-');
    Hive.init(directory.path);
    await Hive.openBox('settings');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  testWidgets(
    'Skip persists completion and replaces onboarding, including after restart',
    (tester) async {
      Widget gate() => FirstRunGate(
        readyBuilder: (_) => const CupertinoApp(home: Text('Your library')),
      );
      await tester.pumpWidget(gate());
      await tester.pump();
      expect(find.byType(OnboardingPage), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Skip'));
        await Hive.box('settings').flush();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(Hive.box('settings').get('walkthroughSeen'), isTrue);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.text('Your library'), findsOneWidget);
      expect(
        Navigator.canPop(tester.element(find.text('Your library'))),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(gate());
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);
    },
  );
}
