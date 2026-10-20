import 'package:http/http.dart' as http;
import 'package:musyn/constants/version.dart';
import 'package:musyn/services/provider_access.dart';

String sanitizeDiagnostics(String text) {
  var clean = ProviderAccess.instance.redact(text);
  clean = clean.replaceAll(
    RegExp(r'https?://[^\s<>]+', caseSensitive: false),
    '[URL redacted]',
  );
  clean = clean.replaceAll(
    RegExp(
      r'(authorization|cookie|set-cookie|api[_-]?key|token|password)\s*[:=][^\n]*',
      caseSensitive: false,
      multiLine: true,
    ),
    '[credential redacted]',
  );
  clean = clean.replaceAll(
    RegExp(r'/(?:private/)?(?:var|Users|data|storage)/[^\s]+'),
    '[local path redacted]',
  );
  clean = clean.replaceAll(
    RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),
    '[email redacted]',
  );
  return clean;
}

class DiagnosticSharing {
  DiagnosticSharing({this.client});
  final http.Client? client;
  Future<Uri> upload(String preview) async {
    final sender = client ?? http.Client();
    try {
      final response = await sender
          .post(
            Uri.parse('https://dpaste.com/api/v2/'),
            headers: {
              'User-Agent':
                  'Musyn/$appVersion (Voryn Labs; user-requested diagnostics)',
            },
            body: {
              'content': sanitizeDiagnostics(preview),
              'title': 'Musyn $appVersion diagnostics',
              'expiry_days': '7',
            },
          )
          .timeout(const Duration(seconds: 20));
      final location = response.headers['location'] ?? response.body.trim();
      final uri = Uri.tryParse(location.replaceAll('"', ''));
      if (response.statusCode != 201 ||
          uri?.scheme != 'https' ||
          uri?.host != 'dpaste.com' ||
          uri!.path.length < 2) {
        throw StateError('Upload failed. No diagnostic link was created.');
      }
      return uri;
    } finally {
      if (client == null) sender.close();
    }
  }

  static Uri issue({
    Uri? log,
  }) => Uri.https('github.com', '/Voryn-Labs/Musyn/issues/new', {
    'title': 'Musyn $appVersion: ',
    'body':
        'Musyn $appVersion\n\nWhat happened?\n\nSteps to reproduce:\n1. \n\nExpected behavior:\n\niOS version and installer:\n\n${log == null ? 'Diagnostics (optional):' : 'Diagnostics (public, expires after 7 days): $log'}\n\nPlease remove any personal information before submitting.',
  });
}
