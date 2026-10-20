import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musyn/services/automatic_artwork_resolver.dart';

const artworkItem = MediaItem(
  id: 'a',
  title: 'Night Drive',
  artist: 'Test Artist',
  album: 'Night Record',
  duration: Duration(minutes: 3),
);
Map<String, dynamic> catalogSong({
  String artist = 'Test Artist',
  String title = 'Night Drive',
  int duration = 180000,
}) => {
  'artistName': artist,
  'trackName': title,
  'trackTimeMillis': duration,
  'collectionId': 123,
  'collectionName': 'Night Record',
};
String albumPage({
  String id = '123',
  String? video = 'https://mvod.itunes.apple.com/art/master.m3u8',
}) =>
    '<script id="serialized-server-data" type="application/json">${jsonEncode({
      'data': [
        {
          'data': {
            'sections': [
              {
                'items': [
                  {
                    'id': 'album-detail-header - $id',
                    'videoArtwork': {
                      'dictionary': {
                        if (video != null) 'motionDetailSquare': {'video': video},
                      },
                    },
                  },
                ],
              },
            ],
          },
        },
      ],
    })}</script>';
const master =
    '#EXTM3U\n#EXT-X-STREAM-INF:RESOLUTION=768x768,CODECS="hvc1",VIDEO-RANGE=SDR\nvariant.m3u8\n';
const media =
    '#EXTM3U\n#EXT-X-MAP:URI="cover.mp4",BYTERANGE="100@0"\n#EXTINF:4,\n#EXT-X-BYTERANGE:900@100\ncover.mp4\n#EXT-X-ENDLIST\n';
http.Response artworkResponse(http.Request request) {
  switch (request.url.host) {
    case 'itunes.apple.com':
      return http.Response(
        jsonEncode({
          'results': [catalogSong()],
        }),
        200,
      );
    case 'music.apple.com':
      return http.Response(albumPage(), 200);
    default:
      if (request.url.path.endsWith('master.m3u8'))
        return http.Response(master, 200);
      if (request.url.path.endsWith('variant.m3u8'))
        return http.Response(media, 200);
      return http.Response.bytes(List.filled(32, 1), 200);
  }
}

void main() {
  test(
    'match tolerates presentation suffixes but rejects versions, artists and durations',
    () {
      expect(
        artworkTrackMatches(
          artworkItem.copyWith(title: 'Night Drive (Official Video)'),
          catalogSong(),
        ),
        isTrue,
      );
      expect(
        artworkTrackMatches(artworkItem, catalogSong(artist: 'Someone Else')),
        isFalse,
      );
      expect(
        artworkTrackMatches(
          artworkItem,
          catalogSong(title: 'Night Drive Live'),
        ),
        isFalse,
      );
      expect(
        artworkTrackMatches(
          artworkItem,
          catalogSong(title: 'Night Drive Remix'),
        ),
        isFalse,
      );
      expect(
        artworkTrackMatches(artworkItem, catalogSong(duration: 240000)),
        isFalse,
      );
      expect(
        artworkTrackMatches(artworkItem.copyWith(artist: null), catalogSong()),
        isFalse,
      );
      expect(
        artworkName('नमस्ते Beyoncé &amp; Friends'),
        'नमस्ते beyoncé friends',
      );
    },
  );
  test(
    'page parser takes only the matched album header and trusted media URLs',
    () {
      expect(
        artworkFromAlbumPage(albumPage(), '123')?.path,
        '/art/master.m3u8',
      );
      expect(artworkFromAlbumPage(albumPage(id: '999'), '123'), isNull);
      expect(
        artworkFromAlbumPage(
          albumPage(video: 'https://example.com/private'),
          '123',
        ),
        isNull,
      );
      expect(artworkFromAlbumPage(albumPage(video: null), '123'), isNull);
      expect(artworkFromAlbumPage('<html>No artwork</html>', '123'), isNull);
    },
  );
  test(
    'rendition chooses a compact SDR cover and rejects encrypted or unrelated shapes',
    () {
      final base = Uri.parse('https://mvod.itunes.apple.com/art/master.m3u8');
      const variants =
          '#EXTM3U\n#EXT-X-STREAM-INF:RESOLUTION=486x486,CODECS="avc1"\nsmall.m3u8\n#EXT-X-STREAM-INF:RESOLUTION=768x768,CODECS="avc1"\navc.m3u8\n#EXT-X-STREAM-INF:RESOLUTION=768x768,CODECS="hvc1"\nhevc.m3u8\n#EXT-X-STREAM-INF:RESOLUTION=2160x2160,CODECS="hvc1"\nlarge.m3u8\n';
      expect(artworkVariant(variants, base)?.path, '/art/hevc.m3u8');
      expect(
        artworkVariant('#EXT-X-SESSION-KEY:METHOD=SAMPLE-AES\n$variants', base),
        isNull,
      );
      expect(
        artworkVariant(
          '#EXT-X-STREAM-INF:RESOLUTION=1920x1080\nlandscape.m3u8',
          base,
        ),
        isNull,
      );
      expect(
        artworkVariant(
          '#EXT-X-STREAM-INF:RESOLUTION=768x768,VIDEO-RANGE=PQ\nhdr.m3u8',
          base,
        ),
        isNull,
      );
    },
  );
  test(
    'single-file HLS preserves real video and refuses DRM, split segments or oversized duration',
    () {
      final base = Uri.parse('https://mvod.itunes.apple.com/art/variant.m3u8');
      expect(artworkWholeFile(media, base)?.path, '/art/cover.mp4');
      expect(
        artworkWholeFile('#EXT-X-KEY:METHOD=AES-128\n$media', base),
        isNull,
      );
      expect(
        artworkWholeFile(
          media.replaceFirst('#EXT-X-ENDLIST', 'other.mp4\n#EXT-X-ENDLIST'),
          base,
        ),
        isNull,
      );
      expect(
        artworkWholeFile(media.replaceFirst('#EXTINF:4,', '#EXTINF:31,'), base),
        isNull,
      );
      expect(
        artworkWholeFile(
          media.replaceAll('cover.mp4', 'https://example.com/private.mp4'),
          base,
        ),
        isNull,
      );
    },
  );
  test(
    'keyless pipeline finds a matched clip without credentials or account cookies',
    () async {
      final seen = <Uri>[];
      final resolver = AutomaticArtworkResolver(
        client: MockClient((request) async {
          seen.add(request.url);
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(request.headers.containsKey('Cookie'), isFalse);
          return artworkResponse(request);
        }),
      );
      addTearDown(resolver.close);
      final clip = await resolver.find(artworkItem, current: () => true);
      expect(
        clip?.movie.toString(),
        'https://mvod.itunes.apple.com/art/cover.mp4',
      );
      expect(clip?.albumId, '123');
      expect(seen.map((u) => u.host), [
        'itunes.apple.com',
        'music.apple.com',
        'mvod.itunes.apple.com',
        'mvod.itunes.apple.com',
      ]);
    },
  );
  test('unmatched track never requests another album cover', () async {
    final resolver = AutomaticArtworkResolver(
      client: MockClient((request) async {
        expect(request.url.host, 'itunes.apple.com');
        return http.Response(
          jsonEncode({
            'results': [catalogSong(artist: 'Wrong Artist')],
          }),
          200,
        );
      }),
    );
    addTearDown(resolver.close);
    expect(await resolver.find(artworkItem, current: () => true), isNull);
  });
  test(
    'redirects cannot escape the provider and throttling is a retryable outcome',
    () async {
      var calls = 0;
      final resolver = AutomaticArtworkResolver(
        client: MockClient((request) async {
          calls++;
          return http.Response(
            '',
            302,
            headers: {'location': 'http://127.0.0.1/private'},
          );
        }),
      );
      addTearDown(resolver.close);
      await expectLater(
        resolver.find(artworkItem, current: () => true),
        throwsFormatException,
      );
      expect(calls, 1);
      final busy = AutomaticArtworkResolver(
        client: MockClient((_) async => http.Response('', 429)),
      );
      addTearDown(busy.close);
      await expectLater(
        busy.find(artworkItem, current: () => true),
        throwsA(isA<ArtworkLookupBusy>()),
      );
    },
  );
  test('superseded lookup makes no request', () async {
    final resolver = AutomaticArtworkResolver(
      client: MockClient((_) async => throw StateError('Must not request')),
    );
    addTearDown(resolver.close);
    await expectLater(
      resolver.find(artworkItem, current: () => false),
      throwsA(isA<ArtworkLookupCancelled>()),
    );
  });
  test(
    'video byte limit is enforced before accepting a large response',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'artwork-download-',
      );
      final file = File('${directory.path}/clip.partial');
      final resolver = AutomaticArtworkResolver(
        client: MockClient.streaming(
          (_, __) async => http.StreamedResponse(
            const Stream<List<int>>.empty(),
            200,
            contentLength: AutomaticArtworkResolver.maxClipBytes + 1,
          ),
        ),
      );
      addTearDown(() async {
        resolver.close();
        await directory.delete(recursive: true);
      });
      await expectLater(
        resolver.download(
          Uri.parse('https://mvod.itunes.apple.com/art/cover.mp4'),
          file,
          current: () => true,
        ),
        throwsFormatException,
      );
      expect(await file.exists(), isFalse);
    },
  );
  test(
    'live public album lookup downloads a real animated artwork asset',
    () async {
      final resolver = AutomaticArtworkResolver();
      try {
        final clip = await resolver.find(
          const MediaItem(
            id: 'live-fixture',
            title: 'Anti-Hero',
            artist: 'Taylor Swift',
            album: 'Midnights',
            duration: Duration(seconds: 200),
          ),
          current: () => true,
        );
        expect(clip, isNotNull);
        final file = File('/private/tmp/musyn-live-automatic-artwork.mp4');
        await resolver.download(clip!.movie, file, current: () => true);
        expect(
          await file.length(),
          inInclusiveRange(100000, AutomaticArtworkResolver.maxClipBytes),
        );
      } finally {
        resolver.close();
      }
    },
    skip: !const bool.fromEnvironment('MUSYN_LIVE_ARTWORK'),
    tags: ['network'],
  );
}
