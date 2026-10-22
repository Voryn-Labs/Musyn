import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/audio/audio_browse_catalog.dart';
import 'package:musyn/services/audio/carplay.dart';
import 'bitchord_ui_test.dart' show UiPlayback;

class CarPlayback extends UiPlayback {
  List<MediaItem> songs = const [
    MediaItem(id: 'a', title: 'A'),
    MediaItem(id: 'b', title: 'B'),
  ];
  int? skipped;
  String? selected;
  @override
  Future<List<MediaItem>> getChildren(
    String id, [
    Map<String, dynamic>? options,
  ]) async => songs;
  @override
  Future<void> skipToSong(int index) async {
    skipped = index;
  }

  @override
  Future<void> playFromMediaId(
    String id, [
    Map<String, dynamic>? extras,
  ]) async {
    selected = id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test-musyn/carplay');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late CarPlayBridge bridge;
  late CarPlayback handler;
  late List<Map> snapshots;
  setUp(() {
    snapshots = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'ready') return false;
      if (call.method == 'setState') snapshots.add(call.arguments as Map);
      return null;
    });
    handler = CarPlayback();
    bridge = CarPlayBridge(channel: channel)..start(handler);
  });
  tearDown(() async {
    await bridge.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'publishes bounded native catalog only while the car is connected',
    () async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(snapshots, isEmpty);
      handler.songs = List.generate(
        130,
        (i) => MediaItem(id: '$i', title: 'Song $i'),
      );
      await bridge.handle(const MethodCall('connection', true));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(snapshots, hasLength(1));
      final sections = snapshots.single['sections'] as List;
      expect(sections, hasLength(4));
      expect(sections.first['items'], hasLength(100));
      await bridge.handle(const MethodCall('connection', false));
      handler.queue.add(handler.songs);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(snapshots, hasLength(1));
    },
  );
  test(
    'queue selections follow IDs across reorder and reject removed entries',
    () async {
      await Future<void>.delayed(Duration.zero);
      await bridge.handle(const MethodCall('connection', true));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      handler.songs = handler.songs.reversed.toList();
      expect(
        await bridge.handle(
          const MethodCall('play', {
            'category': AudioBrowseCatalog.rootQueue,
            'id': 'a',
          }),
        ),
        true,
      );
      expect(handler.skipped, 1);
      handler.songs = [];
      expect(
        await bridge.handle(
          const MethodCall('play', {
            'category': AudioBrowseCatalog.rootQueue,
            'id': 'a',
          }),
        ),
        false,
      );
      expect(
        await bridge.handle(
          const MethodCall('play', {'category': 'untrusted', 'id': 'a'}),
        ),
        false,
      );
    },
  );
  test(
    'library selections start the shared collection at the chosen song',
    () async {
      await Future<void>.delayed(Duration.zero);
      await bridge.handle(const MethodCall('connection', true));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        await bridge.handle(
          const MethodCall('play', {
            'category': AudioBrowseCatalog.rootOffline,
            'id': 'b',
          }),
        ),
        true,
      );
      expect(handler.playedIndex, 1);
      expect(handler.playedPlaylist?['list'][1]['ytid'], 'b');
      expect(handler.skipped, isNull);
    },
  );
}
