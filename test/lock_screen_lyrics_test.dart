import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/lock_screen_lyrics.dart';
import 'package:musyn/services/lyrics_request_cache.dart';
import 'package:musyn/utilities/app_utils.dart';
import 'package:musyn/widgets/now_playing/lyrics/lrc_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test-lock-lyrics');
  final calls = <Map>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.arguments as Map);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  const a = MediaItem(id: 'a', title: 'First', artist: 'Artist');
  const b = MediaItem(id: 'b', title: 'Second', artist: 'Artist');
  test('late lyric lookup cannot replace lyrics after a rapid skip', () async {
    final old = Completer<String?>();
    final service = LockScreenLyrics(
      channel: channel,
      load: (item) =>
          item.id == 'a' ? old.future : Future.value('[00:01]Second line'),
    );
    service.select(a, enabled: true);
    await Future<void>.delayed(Duration.zero);
    final oldWork = service.pending;
    service.select(b, enabled: true);
    await service.pending;
    old.complete('[00:01]Wrong song');
    await oldWork;
    expect(calls.where((c) => c['enabled'] == true).map((c) => c['id']), ['b']);
  });
  test(
    'disabling pending lyrics restores the artist and blocks late updates',
    () async {
      final pending = Completer<String?>();
      final service = LockScreenLyrics(
        channel: channel,
        load: (_) => pending.future,
      );
      service.select(a, enabled: true);
      await Future<void>.delayed(Duration.zero);
      final work = service.pending;
      service.select(a, enabled: false);
      await service.pending;
      pending.complete('[00:01]Not shown');
      await work;
      expect(calls.every((c) => c['enabled'] == false), true);
    },
  );
  test(
    'artist and artwork modes are independent and changes republish',
    () async {
      final service = LockScreenLyrics(
        channel: channel,
        load: (_) async => '[00:01]Line',
      );
      service.select(a, enabled: false, artwork: true);
      await service.pending;
      expect(calls.last['artist'], false);
      expect(calls.last['artwork'], true);
      service.select(a, enabled: true, artwork: true);
      await service.pending;
      expect(calls.last['artist'], true);
      expect(calls.last['artwork'], true);
      service.select(a, enabled: true);
      await service.pending;
      expect(calls.last['artwork'], false);
    },
  );
  test('plain lyrics carry no invented lock-screen timing', () async {
    final service = LockScreenLyrics(
      channel: channel,
      load: (_) async => 'Plain lyrics',
    );
    service.select(a, enabled: true);
    await service.pending;
    expect(calls.last['lines'], isEmpty);
  });
  test(
    'same-track duration and artwork updates do not refetch lyrics',
    () async {
      var loads = 0;
      final service = LockScreenLyrics(
        channel: channel,
        load: (_) async {
          loads++;
          return '[00:02]Line';
        },
      );
      service.select(a, enabled: true);
      await service.pending;
      service.select(
        a.copyWith(duration: const Duration(seconds: 180)),
        enabled: true,
      );
      await service.pending;
      expect(loads, 1);
      expect((calls.last['lines'] as List).single['at'], 2000.0);
    },
  );
  test(
    'player and lock screen join concurrent requests without caching failures',
    () async {
      var loads = 0;
      final pending = Completer<String?>();
      final cache = LyricsRequestCache((artist, title) {
        loads++;
        return pending.future;
      });
      final a = cache.fetch('Artist', 'Song');
      final b = cache.fetch('Artist', 'Song');
      expect(identical(a, b), true);
      pending.complete(null);
      await Future.wait([a, b]);
      await cache.fetch('Artist', 'Song');
      expect(loads, 2);
    },
  );
  test('LRC variants retain repeated and sorted timestamps', () {
    final lines = parseLrcLyrics(
      '[00:12.2][00:32.250]Chorus\n[00:02]First\n[01:90]Invalid',
    );
    expect(lines.map((l) => l.time.inMilliseconds), [2000, 12200, 32250]);
    expect(lines.map((l) => l.text), ['First', 'Chorus', 'Chorus']);
  });
  test('decimal JioSaavn catalogue durations do not become unknown', () {
    expect(parseSongDuration('182.0'), const Duration(seconds: 182));
    expect(parseSongDuration('NaN'), isNull);
    expect(parseSongDuration('Infinity'), isNull);
    expect(parseSongDuration('0.0'), isNull);
  });
}
