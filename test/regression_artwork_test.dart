import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/common_services.dart';
import 'package:musyn/services/io_service.dart';
import 'package:musyn/utilities/artwork_provider.dart';
import 'package:musyn/utilities/mediaitem.dart';

void main() {
  test(
    'display metadata does not stat files and registry clearing removes offline status',
    () {
      final previousDirectory = applicationDirPath;
      final previousSongs = userOfflineSongs.value;
      addTearDown(() {
        applicationDirPath = previousDirectory;
        userOfflineSongs.value = previousSongs;
      });
      applicationDirPath = '/current container';
      userOfflineSongs.value = [
        {
          'ytid': 'abcdefghijk',
          'audioPath': '/old/audio.m4a',
          'artworkPath': '/old/art.jpg',
        },
      ];
      final metadata = IOOverrides.runZoned(
        () => mapToMediaItem({'ytid': 'abcdefghijk', 'title': 'Track'}),
        createFile: (_) => throw StateError(
          'Unexpected filesystem access during display mapping',
        ),
      );
      expect(metadata.artUri?.scheme, 'file');
      expect(metadata.extras?['isOffline'], isTrue);
      userOfflineSongs.value = [];
      expect(
        mapToMediaItem({
          'ytid': 'abcdefghijk',
          'title': 'Track',
        }).extras?['isOffline'],
        isFalse,
      );
    },
  );

  test(
    'local artwork URI decodes spaces instead of using an HTTP provider',
    () {
      final uri = Uri.file('/music covers/album art.jpg');
      final provider = ArtworkProvider.get(uri.toString());
      expect(provider, isA<FileImage>());
      expect((provider as FileImage).file.path, '/music covers/album art.jpg');
    },
  );
}
