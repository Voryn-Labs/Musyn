import 'package:http/http.dart' as http;

/// Headers-only probe. Never collect the body, even if the CDN ignores Range.
Future<bool> isStreamUrlAlive(String url, {String? userAgent}) async {
  final client = http.Client();
  try {
    final uri = Uri.parse(url);
    final headers = <String, String>{
      if (userAgent != null && userAgent.isNotEmpty) 'User-Agent': userAgent,
    };
    final head = await client
        .send(http.Request('HEAD', uri)..headers.addAll(headers))
        .timeout(const Duration(seconds: 4));
    final status = head.statusCode;
    await head.stream.listen((_) {}).cancel();
    if (status == 200 || status == 206) return true;
    if (status != 405) return false;
    final probe = await client
        .send(
          http.Request('GET', uri)
            ..headers.addAll({...headers, 'Range': 'bytes=0-1'}),
        )
        .timeout(const Duration(seconds: 4));
    final valid = probe.statusCode == 200 || probe.statusCode == 206;
    await probe.stream.listen((_) {}).cancel();
    return valid;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}
