import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/utilities/mediaitem.dart';
import 'package:musyn/services/audio/player_artwork_cache.dart';
import 'dart:ui' as ui;
import 'package:musyn/utilities/artwork_provider.dart' show artworkCandidates;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'YouTube cover crop removes black letterbox pixels for Now Playing',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xFF000000), ui.BlendMode.src);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 45, 480, 270),
          ui.Paint()..color = const ui.Color(0xFFFF0066),
        );
        final picture = recorder.endRecording();
        final original = await picture.toImage(480, 360);
        picture.dispose();
        final png = await original.toByteData(format: ui.ImageByteFormat.png);
        original.dispose();
        final square = await PlayerArtworkCache.squareCover(
          png!.buffer.asUint8List(),
          videoThumbnail: true,
        );
        final codec = await ui.instantiateImageCodec(square!);
        final decoded = (await codec.getNextFrame()).image;
        codec.dispose();
        expect(decoded.width, 270);
        expect(decoded.height, 270);
        final rgba = await decoded.toByteData();
        expect(rgba!.getUint8(0), greaterThan(230));
        expect(rgba.getUint8(1), 0);
        expect(rgba.getUint8(2), inInclusiveRange(90, 110));
        decoded.dispose();
      });
    },
  );
  test('large players request HD artwork with a reliable video fallback', () {
    expect(
      artworkCandidates(
        'https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg',
        targetSize: 1024,
      ),
      [
        'https://i.ytimg.com/vi/abcdefghijk/maxresdefault.jpg',
        'https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg',
      ],
    );
    expect(
      upgradeArtworkUrl('https://c.saavncdn.com/album-1500x1500.jpg'),
      'https://c.saavncdn.com/album-1500x1500.jpg',
    );
  });
  test('small YouTube covers are upgraded without downgrading an HQ cover', () {
    expect(
      upgradeArtworkUrl('https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg'),
      'https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg',
    );
    expect(
      upgradeArtworkUrl('https://i.ytimg.com/vi/abcdefghijk/maxresdefault.jpg'),
      'https://i.ytimg.com/vi/abcdefghijk/maxresdefault.jpg',
    );
    expect(
      upgradeArtworkUrl(
        'https://lh3.googleusercontent.com/cover=w60-h60-l90-rj',
        targetSize: 600,
      ),
      'https://lh3.googleusercontent.com/cover=w600-h600-c-l90-rj',
    );
  });
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
