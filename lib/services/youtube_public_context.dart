import 'dart:async';
import 'package:http/http.dart' as http;

/// Refreshes the public WEB_REMIX client version from YouTube itself. This
/// request sends no account cookies and cannot read the user's Google session.
class YouTubePublicContext {
  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
  String _version = '1.20240101.01.00';
  DateTime? _checked;
  Future<String>? _pending;
  Future<String> version() {
    if (_checked != null &&
        DateTime.now().difference(_checked!) < const Duration(hours: 6))
      return Future.value(_version);
    return _pending ??= _refresh().whenComplete(() => _pending = null);
  }

  Future<String> _refresh() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://music.youtube.com/'),
            headers: {
              'User-Agent': userAgent,
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final match = RegExp(
          r'"INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)"',
        ).firstMatch(response.body);
        if (match != null) {
          _version = match.group(1)!;
          _checked = DateTime.now();
          return _version;
        }
      }
    } catch (_) {
      /* Existing client remains a fallback when bootstrap is offline. */
    }
    // Retry soon after a failed bootstrap, without repeating it for every call.
    _checked = DateTime.now().subtract(const Duration(hours: 5, minutes: 59));
    return _version;
  }
}
