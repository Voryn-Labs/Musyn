import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/vocal_reduction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = MediaItem(id: 'entry-a', title: 'A');
  const b = MediaItem(id: 'entry-b', title: 'B');
  late List<String> installed;
  late List<double> levels;
  late VocalReductionController controller;
  VocalReductionController make({
    VocalPrepare? prepare,
    Future<bool> Function(String, String)? install,
    Future<void> Function(double)? mix,
  }) => VocalReductionController(
    prepare:
        prepare ??
        (_, _, progress) async {
          progress('Separating', 0.5);
          return '/local/test.musyn-stems.mov';
        },
    install:
        install ??
        (id, path) async {
          installed.add(id);
          return true;
        },
    mix:
        mix ??
        (level) async {
          levels.add(level);
        },
    cancel: () async {},
  );
  setUp(() {
    installed = [];
    levels = [];
  });
  tearDown(() {
    controller.dispose();
  });
  test(
    'prepared stems retain queue entry identity and vocal control restores original',
    () async {
      controller = make();
      await controller.enable(a);
      expect(installed, ['entry-a']);
      expect(levels, [0]);
      expect(controller.phase, VocalPhase.ready);
      await controller.setLevel(0.4);
      await controller.disable();
      expect(levels, [0, 0.4, 1]);
      expect(controller.wanted, false);
    },
  );
  test(
    'late preparation after skip never installs on a different track',
    () async {
      final preparation = Completer<String>();
      controller = make(prepare: (_, _, _) => preparation.future);
      final work = controller.enable(a);
      controller.select(b);
      preparation.complete('/local/a.musyn-stems.mov');
      await work;
      expect(installed, isEmpty);
      expect(levels, isEmpty);
      expect(controller.phase, VocalPhase.off);
    },
  );
  test('cancel during installation never applies a muted mix', () async {
    final installation = Completer<bool>();
    controller = make(install: (_, _) => installation.future);
    final work = controller.enable(a);
    await Future<void>.delayed(Duration.zero);
    await controller.disable();
    installation.complete(true);
    await work;
    expect(levels, isEmpty);
    expect(controller.phase, VocalPhase.off);
  });
  test(
    'cancel during native mix restores original vocals after mix returns',
    () async {
      final mix = Completer<void>();
      controller = make(
        mix: (level) {
          levels.add(level);
          return level == 0 ? mix.future : Future.value();
        },
      );
      final work = controller.enable(a);
      await Future<void>.delayed(Duration.zero);
      await controller.disable();
      mix.complete();
      await work;
      expect(levels, [0, 1]);
      expect(controller.phase, VocalPhase.off);
    },
  );
  test(
    'metadata refresh does not reset prepared vocals, source changes do',
    () async {
      controller = make();
      await controller.enable(a);
      controller.select(
        a.copyWith(
          duration: const Duration(seconds: 180),
          extras: {'vocalMix': true},
        ),
      );
      expect(controller.phase, VocalPhase.ready);
      controller.select(a.copyWith(extras: {'resolvedSource': 'jiosaavn'}));
      expect(controller.phase, VocalPhase.off);
    },
  );
  test('failure never calls mix or replaces audio', () async {
    controller = make(
      prepare: (_, _, _) => Future.error(StateError('unavailable')),
    );
    await controller.enable(a);
    expect(controller.phase, VocalPhase.failed);
    expect(installed, isEmpty);
    expect(levels, isEmpty);
  });
}
