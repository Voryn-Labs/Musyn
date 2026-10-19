import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/audio/audio_playback_coordinator.dart';
import 'playback_install_test.dart' show ControlledPlayer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'consuming a warm URL applies its headers and provider together',
    () async {
      final player = ControlledPlayer();
      final coordinator = AudioPlaybackCoordinator(audioPlayer: player);
      const url = 'https://rr1.googlevideo.com/videoplayback?expire=9999999999';
      final song = <String, dynamic>{
        'ytid': 'abcdefghijk',
        'resolvedSource': 'jiosaavn',
        '_preloadedStreamUrl': url,
        '_preloadedStreamMetadata': {
          'resolvedSource': 'youtube',
          'resolvedUserAgent': 'prepared-agent',
        },
      };
      expect(await coordinator.getPlaybackUrl(song, {}, isOffline: false), url);
      expect(song['resolvedSource'], 'youtube');
      expect(song['resolvedUserAgent'], 'prepared-agent');
      await player.dispose();
    },
  );
  test(
    'another occurrence consumes cached metadata with the matching URL',
    () async {
      final player = ControlledPlayer();
      final coordinator = AudioPlaybackCoordinator(audioPlayer: player);
      final song = <String, dynamic>{'ytid': 'abcdefghijk'};
      const url = 'https://aac.saavncdn.com/song.mp4';
      expect(
        await coordinator.getPlaybackUrl(
          song,
          {'abcdefghijk': url},
          isOffline: false,
          preloadedMetadata: {
            'abcdefghijk': {
              'resolvedSource': 'jiosaavn',
              'resolvedBitrate': 320,
            },
          },
        ),
        url,
      );
      expect(song['resolvedSource'], 'jiosaavn');
      expect(song['resolvedBitrate'], 320);
      await player.dispose();
    },
  );
}
