import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musyn/services/diagnostic_sharing.dart';
import 'package:musyn/services/provider_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          ProviderAccess.instance.channel,
          (_) async => null,
        );
    await ProviderAccess.instance.save('fixture!');
  });
  test(
    'diagnostics redact configured key, credentials, signed URLs and local identity',
    () {
      final value = sanitizeDiagnostics(
        'key fixture!\nAuthorization: Bearer secret\nCookie: SID=private\nhttps://audio.example/file?token=secret\n/var/mobile/Containers/private/song\nname@example.com\ntrack=Test track elapsed=1',
      );
      for (final secret in [
        'fixture!',
        'secret',
        'SID=',
        'audio.example',
        'Containers/private',
        'name@example.com',
      ]) {
        expect(value, isNot(contains(secret)));
      }
      expect(value, contains('track=Test track elapsed=1'));
    },
  );
  test(
    'upload sends only preview with expiry and accepts a secure dpaste link',
    () async {
      final share = DiagnosticSharing(
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://dpaste.com/api/v2/');
          expect(request.method, 'POST');
          final body = Uri.splitQueryString(request.body);
          expect(body['expiry_days'], '7');
          expect(body['content'], isNot(contains('fixture!')));
          expect(request.headers['User-Agent'], contains('user-requested'));
          return http.Response('https://dpaste.com/EXAMPLE', 201);
        }),
      );
      expect(
        await share.upload('fixture!'),
        Uri.parse('https://dpaste.com/EXAMPLE'),
      );
    },
  );
  test(
    'failed uploads and untrusted response URLs cannot become issue links',
    () async {
      for (final reply in [
        http.Response('denied', 403),
        http.Response('https://evil.example/private', 201),
      ]) {
        final share = DiagnosticSharing(client: MockClient((_) async => reply));
        await expectLater(share.upload('fixture'), throwsStateError);
      }
      final issue = DiagnosticSharing.issue(
        log: Uri.parse('https://dpaste.com/EXAMPLE'),
      );
      expect(issue.host, 'github.com');
      expect(issue.path, '/Voryn-Labs/Musyn/issues/new');
      expect(
        issue.queryParameters['body'],
        contains('https://dpaste.com/EXAMPLE'),
      );
    },
  );
}
