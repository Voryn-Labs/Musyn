import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/widgets/position_slider.dart';
import 'package:musyn/models/position_data.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:rxdart/rxdart.dart';
import 'musyn_ui_test.dart' show UiPlayback;

class SliderProbe extends UiPlayback {
  final positions = BehaviorSubject<PositionData>.seeded(
    PositionData(
      const Duration(seconds: 45),
      const Duration(seconds: 90),
      const Duration(seconds: 180),
    ),
  );
  final seeks = <Duration>[];
  @override
  Stream<PositionData> get positionDataStream => positions.stream;
  @override
  Future<void> seek(Duration value) async {
    seeks.add(value);
  }
}

void main() {
  late SliderProbe handler;
  setUp(() {
    handler = SliderProbe();
    audioHandlerInstance = handler;
  });
  tearDown(() async {
    audioHandlerInstance = null;
    await handler.positions.close();
    await handler.audioPlayer.dispose();
  });
  Future<Rect> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(child: SizedBox(width: 300, child: PositionSlider())),
        ),
      ),
    );
    await tester.pump();
    handler.positions.add(
      PositionData(
        const Duration(seconds: 45),
        const Duration(seconds: 90),
        const Duration(seconds: 180),
      ),
    );
    await tester.pump();
    await tester.pump();
    final target = find.descendant(
      of: find.byType(PositionSlider),
      matching: find.byType(CupertinoSlider),
    );
    expect(target, findsOneWidget);
    return tester.getRect(target);
  }

  testWidgets('quick tap seeks to the touched 75 percent position', (
    tester,
  ) async {
    final rect = await mount(tester);
    await tester.tapAt(rect.topLeft + Offset(22 + (rect.width - 44) * .75, 22));
    await tester.pump();
    expect(handler.seeks, [const Duration(seconds: 135)]);
  });
  testWidgets('cancelled touch resumes live progress without seeking', (
    tester,
  ) async {
    final rect = await mount(tester);
    final gesture = await tester.startGesture(
      rect.topLeft + Offset(22 + (rect.width - 44) * .25, 22),
    );
    await gesture.moveBy(Offset((rect.width - 44) * .5, 0));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.cancel();
    handler.positions.add(
      PositionData(
        const Duration(seconds: 60),
        const Duration(seconds: 90),
        const Duration(seconds: 180),
      ),
    );
    await tester.pump();
    expect(handler.seeks, isEmpty);
    expect(find.text('01:00'), findsOneWidget);
  });
}
