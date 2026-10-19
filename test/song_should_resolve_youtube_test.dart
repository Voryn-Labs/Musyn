import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/utilities/app_utils.dart';
import 'package:musyn/services/settings_manager.dart';

void main() {
  test('force jiosaavn overrides youtube catalog origin', () {
    final song = {
      'ytid': 'abc',
      'catalogOrigin': 'youtube',
      'forceSource': 'jiosaavn',
    };
    expect(songShouldResolveYoutube(song), false);
  });

  test('force youtube overrides jiosaavn preference', () {
    final song = {
      'ytid': 'abc',
      'catalogOrigin': 'youtube',
      'forceSource': 'youtube',
    };
    expect(songShouldResolveYoutube(song), true);
  });

  test('source youtube without catalogOrigin still resolves youtube', () {
    final song = {'ytid': 'abc', 'source': 'youtube'};
    expect(songIsYoutubeCatalog(song), true);
    expect(songShouldResolveYoutube(song), true);
    expect(preferredStreamSourceForSong(song), 'youtube');
  });

  test('auto preference resolves youtube immediately (no Saavn gap)', () {
    final song = {'ytid': 'abc', 'title': 'Some Track', 'artist': 'Someone'};
    // Without a YouTube catalog tag, auto must still prefer YouTube on the
    // playback path so lock-screen transitions never wait on Saavn search.
    expect(songShouldResolveYoutube(song), true);
  });

  test('warm URL must match its resolved provider', () {
    final song = {
      'ytid': 'abc',
      'resolvedSource': 'jiosaavn',
      'source': 'youtube',
    };
    expect(
      streamUrlMatchesPreferredSource(
        'https://rr1---sn-test.googlevideo.com/videoplayback?expire=9999999999',
        song,
      ),
      false,
    );
    expect(
      streamUrlMatchesPreferredSource(
        'https://aac.saavncdn.com/song.mp4',
        song,
      ),
      true,
    );
  });

  test('cached jiosaavn resolvedSource skips youtube-first path', () {
    final song = {'ytid': 'abc', 'resolvedSource': 'jiosaavn'};
    expect(songShouldResolveYoutube(song), false);
  });

  test('saavn URL is not treated as youtube playback URL', () {
    expect(
      isUsableYoutubePlaybackUrl('https://aac.saavncdn.com/song.mp4'),
      false,
    );
  });

  test('googlevideo URL is treated as youtube playback URL', () {
    expect(
      isUsableYoutubePlaybackUrl(
        'https://rr1---sn-test.googlevideo.com/videoplayback?expire=9999999999',
      ),
      true,
    );
  });
  test(
    'explicit selection overrides prepared provider and auto accepts either',
    () {
      const youtube =
          'https://rr1.googlevideo.com/videoplayback?expire=9999999999';
      const saavn = 'https://aac.saavncdn.com/song.mp4';
      expect(
        streamUrlMatchesPreferredSource(youtube, {
          'resolvedSource': 'youtube',
          'forceSource': 'jiosaavn',
        }),
        isFalse,
      );
      final old = preferredSource.value;
      addTearDown(() => preferredSource.value = old);
      preferredSource.value = 'auto';
      expect(streamUrlMatchesPreferredSource(youtube, {}), isTrue);
      expect(streamUrlMatchesPreferredSource(saavn, {}), isTrue);
      preferredSource.value = 'jiosaavn';
      final recommendation = {
        'source': 'youtube-recommended',
        'catalogOrigin': 'youtube',
      };
      expect(songShouldResolveYoutube(recommendation), isFalse);
      expect(preferredStreamSourceForSong(recommendation), 'jiosaavn');
    },
  );
  test(
    'global provider applies across catalogues after selection is cleared',
    () {
      final previous = preferredSource.value;
      addTearDown(() => preferredSource.value = previous);
      preferredSource.value = 'jiosaavn';
      final song = <String, dynamic>{
        'ytid': 'abcdefghijk',
        'source': 'youtube',
        'catalogOrigin': 'youtube',
        'resolvedSource': 'youtube',
        'resolvedUserAgent': 'old-agent',
        'forceSource': 'youtube',
        '_preloadedStreamUrl': 'old',
        '_preloadedStreamMetadata': {'resolvedSource': 'youtube'},
      };
      clearSongStreamSelection(song);
      expect(song['ytid'], 'abcdefghijk');
      expect(song['catalogOrigin'], 'youtube');
      expect(song.containsKey('_preloadedStreamMetadata'), isFalse);
      expect(song.containsKey('resolvedUserAgent'), isFalse);
      expect(preferredStreamSourceForSong(song), 'jiosaavn');
      expect(songShouldResolveYoutube(song), isFalse);
      preferredSource.value = 'youtube';
      expect(songShouldResolveYoutube(song), isTrue);
    },
  );
}
