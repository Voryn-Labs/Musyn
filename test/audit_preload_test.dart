import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/audio/audio_preload_cache.dart';
import 'package:musyn/services/audio/audio_preload_service.dart';

void main() {
  test(
    'timeout does not release a still-running request or publish its late URL',
    () async {
      final cache = AudioPreloadCache();
      final response = Completer<String?>();
      final service = AudioPreloadService(
        cache: cache,
        fetchTimeout: const Duration(milliseconds: 1),
        fetchUrl: (_) => response.future,
      );
      final song = <String, dynamic>{'ytid': 'abcdefghijk'};
      await service.preloadSingle(
        song,
        offlineModeEnabled: false,
        isLoadInProgress: () => false,
      );
      expect(cache.activeCount, 1);
      response.complete('https://aac.saavncdn.com/test.mp4');
      await Future<void>.delayed(Duration.zero);
      expect(cache.activeCount, 0);
      expect(cache.streamUrls, isEmpty);
      expect(song['_preloadedStreamUrl'], isNull);
    },
  );

  for (final reset in [false, true]) {
    test(
      '${reset ? "reset" : "cleanup"} retains running request until completion',
      () async {
        final cache = AudioPreloadCache();
        final response = Completer<String?>();
        var requests = 0;
        final service = AudioPreloadService(
          cache: cache,
          fetchUrl: (_) {
            requests++;
            return response.future;
          },
        );
        final song = <String, dynamic>{'ytid': 'abcdefghijk'};
        final pending = service.preloadSingle(
          song,
          offlineModeEnabled: false,
          isLoadInProgress: () => false,
        );
        expect(cache.activeCount, 1);
        if (reset) {
          cache.reset();
        } else {
          service.cleanupStaleForYtids({});
        }
        expect(cache.activeCount, 1);
        await service.preloadSingle(
          {'ytid': 'new_song_12'},
          offlineModeEnabled: false,
          isLoadInProgress: () => false,
        );
        expect(requests, 1);
        response.complete('https://aac.saavncdn.com/test.mp4');
        await pending;
        expect(cache.activeCount, 0);
        expect(cache.streamUrls, isEmpty);
        expect(song['_preloadedStreamUrl'], isNull);
      },
    );
  }
  test(
    'preload isolates active metadata but retains the URL descriptor',
    () async {
      final cache = AudioPreloadCache();
      final song = <String, dynamic>{
        'ytid': 'abcdefghijk',
        'resolvedSource': 'jiosaavn',
      };
      final service = AudioPreloadService(
        cache: cache,
        fetchUrl: (copy) async {
          copy['resolvedSource'] = 'youtube';
          copy['resolvedUserAgent'] = 'resolver-agent';
          copy['resolvedItag'] = 140;
          return 'https://rr1.googlevideo.com/videoplayback?expire=9999999999';
        },
      );
      await service.preloadSingle(
        song,
        offlineModeEnabled: false,
        isLoadInProgress: () => false,
      );
      expect(song['resolvedSource'], 'jiosaavn');
      expect(song['resolvedUserAgent'], isNull);
      expect(
        cache.streamMetadata['abcdefghijk']!['resolvedUserAgent'],
        'resolver-agent',
      );
      expect(
        (song['_preloadedStreamMetadata'] as Map)['resolvedSource'],
        'youtube',
      );
      cache.drop('abcdefghijk');
      expect(cache.streamMetadata, isEmpty);
    },
  );
}
