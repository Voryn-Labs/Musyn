import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musyn/services/automatic_artwork_resolver.dart';
import 'package:musyn/services/automatic_artwork_store.dart';

const first = MediaItem(id: 'a', title: 'First Song', artist: 'Test Artist');
const second = MediaItem(id: 'b', title: 'Second Song', artist: 'Test Artist');

class FakeArtworkResolver extends AutomaticArtworkResolver {
  FakeArtworkResolver(this.lookup);
  final Future<ArtworkClip?> Function(MediaItem) lookup;
  bool closed = false;
  @override
  Future<ArtworkClip?> find(
    MediaItem item, {
    required bool Function() current,
  }) => lookup(item);
  @override
  Future<void> download(
    Uri uri,
    File destination, {
    required bool Function() current,
  }) async {
    if (!current()) throw ArtworkLookupCancelled();
    await destination.writeAsBytes([1, 2, 3]);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

ArtworkClip clip(String id) =>
    ArtworkClip(Uri.parse('https://mvod.itunes.apple.com/$id.mp4'), id);
Future<void> settle(AutomaticArtworkStore store) async {
  await Future<void>.delayed(Duration.zero);
  await store.pending;
}

void main() {
  late Directory root;
  late Box cache;
  final stores = <AutomaticArtworkStore>[];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('musyn-artwork-cache-');
    Hive.init(root.path);
    cache = await Hive.openBox('artwork');
  });
  tearDown(() async {
    for (final store in stores) {
      store.dispose();
      await store.pending;
    }
    stores.clear();
    await Hive.close();
    await root.delete(recursive: true);
  });
  AutomaticArtworkStore make({
    required Future<ArtworkClip?> Function(MediaItem) lookup,
    Future<bool> Function(String)? validate,
    Future<bool> Function()? canFetch,
    Future<Set<String>> Function()? retainedPaths,
    DateTime Function()? now,
    Duration debounce = Duration.zero,
  }) {
    final store = AutomaticArtworkStore(
      directory: Directory('${root.path}/clips'),
      cache: cache,
      validate: validate ?? (_) async => true,
      canFetch: canFetch ?? () async => true,
      retainedPaths: retainedPaths,
      resolverFactory: () => FakeArtworkResolver(lookup),
      debounce: debounce,
      minimumLookupInterval: Duration.zero,
      now: now,
    );
    stores.add(store);
    return store;
  }

  test(
    'automatic fetch caches a clip and reuses it across provider IDs and relaunch',
    () async {
      var calls = 0;
      final store = make(
        lookup: (_) async {
          calls++;
          return clip('album');
        },
      );
      store.select(first, enabled: true);
      await settle(store);
      final path = store.fileFor('a');
      expect(path, isNotNull);
      expect(File(path!).existsSync(), true);
      final restored = make(
        lookup: (_) async {
          calls++;
          throw StateError('Cache should be used');
        },
      );
      restored.select(first.copyWith(id: 'other-provider'), enabled: true);
      await settle(restored);
      expect(restored.fileFor('other-provider'), path);
      expect(calls, 1);
    },
  );
  test(
    'rapid selection cancels older results and never assigns their artwork to the current track',
    () async {
      final delayed = Completer<ArtworkClip?>();
      final store = make(
        lookup: (item) async => item.id == 'a' ? delayed.future : clip('b'),
      );
      store.select(first, enabled: true);
      await Future<void>.delayed(Duration.zero);
      final oldWork = store.pending;
      store.select(second, enabled: true);
      await settle(store);
      delayed.complete(clip('a'));
      await oldWork;
      expect(store.fileFor('a'), isNull);
      expect(store.fileFor('b'), isNotNull);
    },
  );
  test(
    'opt-out while a lookup is pending cannot publish a late clip',
    () async {
      final delayed = Completer<ArtworkClip?>();
      final store = make(lookup: (_) => delayed.future);
      store.select(first, enabled: true);
      await Future<void>.delayed(Duration.zero);
      store.select(first, enabled: false);
      delayed.complete(clip('a'));
      await store.pending;
      expect(store.fileFor('a'), isNull);
      expect(cache.isEmpty, true);
    },
  );
  test(
    'debounce skips transient selections and calls only the final one',
    () async {
      final seen = <String>[];
      final store = make(
        debounce: const Duration(milliseconds: 10),
        lookup: (item) async {
          seen.add(item.id);
          return null;
        },
      );
      store.select(first, enabled: true);
      store.select(second, enabled: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.pending;
      expect(seen, ['b']);
    },
  );
  test(
    'unsupported network conditions suppress work without caching a false absence',
    () async {
      var calls = 0;
      final store = make(
        canFetch: () async => false,
        lookup: (_) async {
          calls++;
          return clip('a');
        },
      );
      store.select(first, enabled: true);
      await settle(store);
      expect(calls, 0);
      expect(cache.isEmpty, true);
    },
  );
  test(
    'no-asset cache expires while transient failures are retried later',
    () async {
      var time = DateTime(2026, 10, 20);
      var calls = 0;
      final store = make(
        now: () => time,
        lookup: (_) async {
          calls++;
          return null;
        },
      );
      store.select(first, enabled: true);
      await settle(store);
      store.select(null, enabled: false);
      store.select(first, enabled: true);
      await settle(store);
      expect(calls, 1);
      time = time.add(const Duration(days: 2));
      store.select(null, enabled: false);
      store.select(first, enabled: true);
      await settle(store);
      expect(calls, 2);
      var attempts = 0;
      final retry = make(
        now: () => time,
        lookup: (_) async {
          attempts++;
          if (attempts == 1) throw const HttpException('Network');
          return clip('b');
        },
      );
      retry.select(second, enabled: true);
      await settle(retry);
      expect(retry.fileFor('b'), isNull);
      time = time.add(const Duration(minutes: 3));
      retry.select(null, enabled: false);
      retry.select(second, enabled: true);
      await settle(retry);
      expect(attempts, 2);
      expect(retry.fileFor('b'), isNotNull);
    },
  );
  test(
    'invalid clips never enter the cache and partial downloads are removed',
    () async {
      final store = make(
        validate: (_) async => false,
        lookup: (_) async => clip('a'),
      );
      store.select(first, enabled: true);
      await settle(store);
      expect(store.fileFor('a'), isNull);
      expect(cache.isEmpty, true);
      expect(await store.directory.list().length, 0);
    },
  );
  test(
    'changed metadata for the same ID clears its earlier artwork immediately',
    () async {
      final delayed = Completer<ArtworkClip?>();
      final store = make(
        lookup: (item) async =>
            item.title == first.title ? clip('first') : delayed.future,
      );
      store.select(first, enabled: true);
      await settle(store);
      final old = store.fileFor('a');
      expect(old, isNotNull);
      store.select(first.copyWith(title: 'Different Recording'), enabled: true);
      expect(store.fileFor('a'), isNull);
      await Future<void>.delayed(Duration.zero);
      delayed.complete(clip('changed'));
      await store.pending;
      expect(store.fileFor('a'), isNotNull);
      expect(store.fileFor('a'), isNot(old));
    },
  );
  test(
    'provider refusal pauses lookups across tracks without negative caching',
    () async {
      var time = DateTime(2026, 10, 20);
      var calls = 0;
      final store = make(
        now: () => time,
        lookup: (_) async {
          calls++;
          if (calls == 1) throw ArtworkLookupBusy();
          return clip('a');
        },
      );
      store.select(first, enabled: true);
      await settle(store);
      store.select(second, enabled: true);
      await settle(store);
      expect(calls, 1);
      expect(cache.isEmpty, true);
      time = time.add(const Duration(minutes: 11));
      store.select(null, enabled: false);
      store.select(first, enabled: true);
      await settle(store);
      expect(calls, 2);
      expect(store.fileFor('a'), isNotNull);
    },
  );
  test(
    'cache byte budget is enforced while protecting the new current clip',
    () async {
      final store = make(lookup: (_) async => clip('a'));
      await store.directory.create(recursive: true);
      for (var i = 0; i < 8; i++) {
        final file = await File(
          '${store.directory.path}/old$i.mp4',
        ).open(mode: FileMode.write);
        await file.truncate(10 * 1024 * 1024);
        await file.close();
      }
      store.select(first, enabled: true);
      await settle(store);
      var bytes = 0;
      await for (final file in store.directory.list()) {
        bytes += (await file.stat()).size;
      }
      expect(bytes, lessThanOrEqualTo(AutomaticArtworkStore.maxCacheBytes));
      expect(store.fileFor('a'), isNotNull);
    },
  );
  test('clear releases native artwork before deleting its file', () async {
    final store = make(lookup: (_) async => clip('a'));
    store.select(first, enabled: true);
    await settle(store);
    final path = store.fileFor('a')!;
    var released = false;
    await store.clear(
      beforeDelete: () async {
        expect(store.fileFor('a'), isNull);
        expect(File(path).existsSync(), true);
        released = true;
      },
    );
    expect(released, true);
    expect(File(path).existsSync(), false);
  });
  test('pruning retains an older clip still published by iOS', () async {
    final pinned = '${root.path}/clips/pinned.mp4';
    final store = make(
      lookup: (_) async => clip('a'),
      retainedPaths: () async => {pinned},
    );
    await store.directory.create(recursive: true);
    final file = await File(pinned).writeAsBytes([1]);
    await file.setLastModified(DateTime(2000));
    for (var i = 0; i < 19; i++) {
      await File('${store.directory.path}/old$i.mp4').writeAsBytes([1]);
    }
    store.select(first, enabled: true);
    await settle(store);
    expect(await file.exists(), true);
    expect(
      await store.directory.list().length,
      AutomaticArtworkStore.maxCacheFiles,
    );
    expect(store.fileFor('a'), isNotNull);
  });
  test('cache stays bounded and retains the current clip', () async {
    final store = make(lookup: (item) async => clip(item.id));
    for (var i = 0; i < 22; i++) {
      store.select(
        MediaItem(id: '$i', title: 'Song $i', artist: 'Artist'),
        enabled: true,
      );
      await settle(store);
    }
    expect(
      await store.directory.list().length,
      lessThanOrEqualTo(AutomaticArtworkStore.maxCacheFiles),
    );
    expect(store.fileFor('21'), isNotNull);
    await store.clear();
    expect(store.fileFor('21'), isNull);
    expect(cache.isEmpty, true);
  });
}
