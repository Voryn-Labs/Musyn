import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:musyn/services/audio/playback_stall_watch.dart';
import 'package:musyn/services/bounded_jobs.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/deferred_links.dart';
import 'package:musyn/services/stream_url_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a callback gap after suspension cannot skip a ready track', () {
    final watch = PlaybackStallWatch();
    final start = DateTime(2026);
    StallAction tick(int seconds, ProcessingState state) => watch.sample(
      now: start.add(Duration(seconds: seconds)),
      position: const Duration(seconds: 20),
      playing: true,
      state: state,
    );
    expect(tick(0, ProcessingState.ready), StallAction.wait);
    expect(tick(2, ProcessingState.ready), StallAction.wait);
    expect(tick(60, ProcessingState.ready), StallAction.wait);
    for (var i = 62; i <= 72; i += 2) {
      expect(tick(i, ProcessingState.ready), StallAction.wait);
    }
    expect(tick(74, ProcessingState.ready), StallAction.resumeCurrent);
  });
  test('explicit ended state advances only after fresh observation', () {
    final watch = PlaybackStallWatch();
    final start = DateTime(2026);
    StallAction tick(int seconds) => watch.sample(
      now: start.add(Duration(seconds: seconds)),
      position: const Duration(seconds: 180),
      playing: false,
      state: ProcessingState.completed,
    );
    expect(tick(0), StallAction.wait);
    expect(tick(2), StallAction.advanceEnded);
    expect(tick(60), StallAction.wait);
    expect(tick(62), StallAction.advanceEnded);
  });
  test(
    'cold-start links wait for navigator, deduplicate and drain in order',
    () async {
      final imported = <Uri>[];
      final inbox = DeferredLinks((uri) async {
        imported.add(uri);
      });
      final a = Uri.parse('musyn://playlist/custom/a');
      final b = Uri.parse('musyn://playlist/custom/b');
      inbox.receive(a);
      inbox.receive(a);
      inbox.receive(b);
      await inbox.pending;
      expect(imported, isEmpty);
      inbox.attach();
      await inbox.pending;
      expect(imported, [a, b]);
      inbox.detach();
      inbox.receive(a);
      await inbox.pending;
      expect(imported.length, 2);
      inbox.attach();
      await inbox.pending;
      expect(imported, [a, b, a]);
    },
  );
  test(
    'artwork capacity retains existing joins instead of decoding twice',
    () async {
      final jobs = BoundedJobs<int, int>(capacity: 40);
      final finish = Completer<int>();
      var loads = 0;
      Future<int?> load() {
        loads++;
        return finish.future;
      }

      final first = jobs.run(0, load);
      for (var i = 1; i < 40; i++) {
        jobs.run(i, load);
      }
      expect(identical(jobs.run(0, load), first), true);
      expect(await jobs.run(40, load), isNull);
      expect(loads, 40);
      finish.complete(3);
      await jobs.drain();
      expect(await jobs.run(40, () async => 4), 4);
    },
  );
  test(
    'stream probe cancels an ignored Range body and closes its client',
    () async {
      final client = HeaderOnlyClient();
      final alive = await http.runWithClient(
        () => isStreamUrlAlive('https://cdn.example/audio'),
        () => client,
      );
      expect(alive, true);
      expect(client.requests, ['HEAD', 'GET']);
      expect(client.cancelled, 2);
      expect(client.closed, true);
    },
  );
  group('persistent cache', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('musyn-audit-cache-');
      Hive.init(directory.path);
      await Hive.openBox('cache');
    });
    tearDown(() async {
      await clearAllCache();
      await Hive.close();
      await directory.delete(recursive: true);
    });
    test(
      'launch cleanup keeps inline artwork timestamps for seven days',
      () async {
        final box = Hive.box('cache');
        final now = DateTime.now();
        await box.put('automatic-artwork:kept', {
          'at': now.subtract(const Duration(days: 6)).millisecondsSinceEpoch,
          'file': 'cover.mp4',
        });
        await box.put('automatic-artwork:old', {
          'at': now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
          'file': 'old.mp4',
        });
        await box.put('automatic-artwork:missing', {
          'at': now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
          'missing': true,
        });
        await box.put('invalid', []);
        await cleanupOldCacheEntries();
        expect(box.containsKey('automatic-artwork:kept'), true);
        expect(box.containsKey('automatic-artwork:old'), false);
        expect(box.containsKey('automatic-artwork:missing'), false);
        expect(box.containsKey('invalid'), false);
        await clearAllCache();
        expect(box.containsKey('automatic-artwork:kept'), true);
      },
    );
    test(
      'nested cached objects are isolated from input and return-value mutation',
      () async {
        final input = {
          'list': [
            {'title': 'Original'},
          ],
        };
        await addOrUpdateData('cache', 'song_snapshot', input);
        input['list']![0]['title'] = 'Input mutation';
        final first = await getData('cache', 'song_snapshot') as Map;
        expect(first['list'][0]['title'], 'Original');
        first['list'][0]['title'] = 'Output mutation';
        final second = await getData('cache', 'song_snapshot') as Map;
        expect(second['list'][0]['title'], 'Original');
        expect(
          await getData(
            'cache',
            'song_snapshot',
            cachingDuration: Duration.zero,
          ),
          isNull,
        );
      },
    );
  });
}

class HeaderOnlyClient extends http.BaseClient {
  final requests = <String>[];
  var cancelled = 0;
  var closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.method);
    if (request.method == 'GET') expect(request.headers['Range'], 'bytes=0-1');
    // The server advertises an unlimited body. The probe must never collect it.
    final stream = StreamController<List<int>>(
      onListen: () {},
      onCancel: () {
        cancelled++;
      },
    );
    return http.StreamedResponse(
      stream.stream,
      request.method == 'HEAD' ? 405 : 200,
    );
  }

  @override
  void close() {
    closed = true;
  }
}
