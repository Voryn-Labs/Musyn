import 'package:flutter_test/flutter_test.dart';
import 'package:musified/utilities/mediaitem.dart';

void main() {
  test(
    'an audio provider change does not replace the selected album artwork',
    () {
      final url = resolveMediaArtworkUrl({
        'catalogImage': 'https://covers.example/album.jpg',
        'highResImage': 'https://saavncdn.com/other-album-500x500.jpg',
        'resolvedSource': 'jiosaavn',
      }, ytid: 'abcdefghijk');
      expect(url, 'https://covers.example/album.jpg');
    },
  );

  test(
    'valid catalogue cover is not replaced by a YouTube video thumbnail',
    () {
      expect(
        resolveMediaArtworkUrl({
          'source': 'youtube',
          'image': 'https://covers.example/album.jpg',
        }, ytid: 'abcdefghijk'),
        'https://covers.example/album.jpg',
      );
    },
  );

  test('a Saavn identifier never becomes a broken YouTube thumbnail URL', () {
    expect(
      resolveMediaArtworkUrl({'source': 'saavn'}, ytid: 'saavn_track_12345'),
      isNull,
    );
  });
}
