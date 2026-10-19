import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/widgets/musyn_bootstrap.dart';

void main() {
  testWidgets('launch branding stays while initialization runs, then opens app', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(MusynBootstrap(initialize: (report) { report('Starting the player'); return pending.future; }, readyBuilder: (_) => const CupertinoApp(home: Text('Library ready'))));
    await tester.pump();
    expect(find.text('Musyn'), findsOneWidget);
    expect(find.text('By Voryn Labs'), findsOneWidget);
    expect(find.text('Starting the player'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Library ready'), findsOneWidget);
  });
  testWidgets('startup failure exposes working retry without an artificial delay', (tester) async {
    var calls = 0;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MusynBootstrap(initialize: (_) async { if (++calls == 1) throw StateError('test'); }, readyBuilder: (_) => const CupertinoApp(home: Text('Library ready'))));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Library ready'), findsOneWidget);
  });
}
