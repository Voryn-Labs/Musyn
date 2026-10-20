import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/audio/stream_resolution_pool.dart';

void main() {
  test('foreground tap joins warmup and keeps its queue identity', () async {
    final pool = StreamResolutionPool();
    final response = Completer<String?>();
    var requests = 0;
    Future<String?> lookup(Map song) {
      requests++;
      song.addAll({'resolvedSource': 'youtube', 'duration': 180});
      return response.future;
    }

    final warm = <String, dynamic>{'ytid': 'abcdefghijk', 'id': 'warm-entry'};
    final tapped = <String, dynamic>{
      'ytid': 'abcdefghijk',
      'id': 'selected-entry',
    };
    final a = pool.resolve(('abcdefghijk', 'youtube'), warm, lookup);
    final b = pool.resolve(('abcdefghijk', 'youtube'), tapped, lookup);
    expect(requests, 1);
    response.complete('https://rr1.googlevideo.com/audio');
    expect(await a, await b);
    expect(tapped['id'], 'selected-entry');
    expect(tapped['resolvedSource'], 'youtube');
    expect(tapped['duration'], 180);
  });

  test('skipped warmup cannot cancel a joined foreground selection', () async {
    final pool = StreamResolutionPool();
    final response = Completer<String?>();
    var abandoned = false;
    final warm = <String, dynamic>{};
    final selected = <String, dynamic>{};
    Future<String?> lookup(Map song) {
      song['resolvedSource'] = 'youtube';
      return response.future;
    }

    final a = pool.resolve('song', warm, lookup, abandon: () => abandoned);
    final b = pool.resolve('song', selected, lookup);
    abandoned = true;
    response.complete('audio');
    expect(await a, isNull);
    expect(await b, 'audio');
    expect(warm, isEmpty);
    expect(selected['resolvedSource'], 'youtube');
  });

  test(
    'different provider or quality does not join an incompatible lookup',
    () async {
      final pool = StreamResolutionPool();
      final response = Completer<String?>();
      final a = pool.resolve(
        ('song', 'youtube', '128'),
        {},
        (_) => response.future,
      );
      final b = pool.resolve(
        ('song', 'jiosaavn', '320'),
        {},
        (_) async => 'saavn',
      );
      expect(await b, 'saavn');
      response.complete('youtube');
      expect(await a, 'youtube');
    },
  );

  test('failed lookup is released so the next tap can retry', () async {
    final pool = StreamResolutionPool();
    await expectLater(
      pool.resolve('song', {}, (_) async => throw StateError('offline')),
      throwsStateError,
    );
    expect(
      await pool.resolve('song', {}, (_) async => 'recovered'),
      'recovered',
    );
  });
}
