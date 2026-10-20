import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/provider_access.dart';
import 'package:musyn/services/jiosaavn_service.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/utilities/app_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? stored;
  setUp(() async {
    stored = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProviderAccess.instance.channel, (
          call,
        ) async {
          switch (call.method) {
            case 'write':
              stored = (call.arguments as Map)['value'] as String;
              return null;
            case 'delete':
              stored = null;
              return null;
            case 'read':
              return stored;
          }
          throw StateError('Unexpected method');
        });
    await ProviderAccess.instance.initialize();
    jiosaavnEnabled.value = true;
  });
  test('missing key blocks decoded URLs and prepared Saavn streams', () async {
    expect(await JioSaavnService().getStreamUrl('not-valid-data'), isNull);
    expect(
      streamUrlMatchesPreferredSource('https://aac.saavncdn.com/track.mp4', {
        'forceSource': 'jiosaavn',
      }),
      isFalse,
    );
    expect(
      streamUrlMatchesPreferredSource(
        'https://rr1.googlevideo.com/videoplayback?expire=9999999999',
        {'forceSource': 'youtube'},
      ),
      isTrue,
    );
  });
  test(
    'user-provided key decrypts fixture and removal revokes stream access',
    () async {
      await ProviderAccess.instance.save('fixture!');
      final encrypted = base64Encode(
        DES(
          key: utf8.encode('fixture!'),
          paddingType: DESPaddingType.PKCS7,
        ).encrypt(
          utf8.encode('https://aac.saavncdn.com/fixture_96.mp4?token=fake'),
        ),
      );
      expect(
        await JioSaavnService().getStreamUrl(encrypted),
        'https://aac.saavncdn.com/fixture_320.mp4?token=fake',
      );
      await ProviderAccess.instance.initialize();
      expect(ProviderAccess.instance.configured, isTrue);
      await ProviderAccess.instance.remove();
      expect(await JioSaavnService().getStreamUrl(encrypted), isNull);
      expect(stored, isNull);
    },
  );
  test(
    'invalid format never writes Keychain and storage failure is not accepted',
    () async {
      await expectLater(
        ProviderAccess.instance.save('short'),
        throwsFormatException,
      );
      expect(stored, isNull);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            ProviderAccess.instance.channel,
            (_) async => throw PlatformException(code: 'locked'),
          );
      await expectLater(
        ProviderAccess.instance.save('fixture!'),
        throwsA(isA<PlatformException>()),
      );
      expect(ProviderAccess.instance.configured, isFalse);
    },
  );
}
