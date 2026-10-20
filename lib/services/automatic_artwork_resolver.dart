import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

/// Public album pages, not a web-player token or another app's session.
class ArtworkLookupBusy implements Exception {}

class ArtworkLookupCancelled implements Exception {}

class ArtworkClip {
  const ArtworkClip(this.movie, this.albumId);
  final Uri movie;
  final String albumId;
}

String artworkName(String value) => html
    .parseFragment(value)
    .text!
    .toLowerCase()
    .replaceAll(RegExp(r'[’‘`\u0027]'), '')
    .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')
    .trim();

String artworkTitle(String value) => artworkName(
  value.replaceAll(
    RegExp(
      r'[\[(](?:official[^\])]*|music video|lyric(?:s| video)?|audio|video|visuali[sz]er|hd|4k)[\])]',
      caseSensitive: false,
    ),
    ' ',
  ),
);

bool _artistMatches(String wanted, String found) {
  final a = artworkName(wanted), b = artworkName(found);
  return a.isNotEmpty &&
      b.isNotEmpty &&
      (' $a '.contains(' $b ') || ' $b '.contains(' $a '));
}

bool artworkTrackMatches(MediaItem item, Map candidate) {
  if (!_artistMatches(
    item.artist ?? '',
    candidate['artistName']?.toString() ?? '',
  ))
    return false;
  final a = artworkTitle(item.title),
      b = artworkTitle(candidate['trackName']?.toString() ?? '');
  if (a.isEmpty || b.isEmpty) return false;
  final versions = RegExp(
    r'\b(live|remix|cover|instrumental|karaoke|acoustic|slowed|sped)\b',
  );
  final av = versions.allMatches(a).map((m) => m[0]).toSet();
  final bv = versions.allMatches(b).map((m) => m[0]).toSet();
  if (av.length != bv.length || !av.containsAll(bv)) return false;
  final wordsA = a.split(' ').toSet(), wordsB = b.split(' ').toSet();
  final overlap = wordsA.intersection(wordsB).length;
  if (a != b && (overlap < 2 || overlap / wordsA.union(wordsB).length < .8))
    return false;
  final ms = candidate['trackTimeMillis'];
  final duration = item.duration;
  if (duration != null &&
      duration.inSeconds > 0 &&
      ms is num &&
      ms > 0 &&
      (duration.inMilliseconds - ms).abs() > 6000)
    return false;
  return true;
}

bool artworkMediaUrl(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    uri.port == 443 &&
    (uri.host.endsWith('.itunes.apple.com') ||
        uri.host.endsWith('.mzstatic.com'));

Uri? artworkFromAlbumPage(String page, String albumId) {
  final document = html.parse(page);
  final encoded = document.querySelector('script#serialized-server-data')?.text;
  if (encoded == null) return null;
  final data = jsonDecode(encoded);
  Uri? walk(dynamic node) {
    if (node is Map) {
      // Never take artwork from related/recommended albums on the same page.
      if (node['id'] == 'album-detail-header - $albumId') {
        for (final field in ['videoArtwork', 'tallVideoArtwork']) {
          final artwork = node[field];
          final dictionary = artwork is Map ? artwork['dictionary'] : null;
          if (dictionary is! Map) continue;
          for (final key in [
            'motionSquareVideo1x1',
            'motionDetailSquare',
            'motionTallVideo3x4',
            'motionDetailTall',
          ]) {
            final entry = dictionary[key];
            final value = entry is Map ? entry['video'] : null;
            final uri = value is String ? Uri.tryParse(value) : null;
            if (uri != null && artworkMediaUrl(uri)) return uri;
          }
        }
        return null;
      }
      for (final value in node.values) {
        final found = walk(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = walk(value);
        if (found != null) return found;
      }
    }
    return null;
  }

  return walk(data);
}

String? _parseAlbumArtwork((String, String) payload) =>
    artworkFromAlbumPage(payload.$1, payload.$2)?.toString();

Uri? artworkVariant(String master, Uri base) {
  if (RegExp(
    r'#EXT-X-(?:SESSION-)?KEY:(?![^\r\n]*METHOD=NONE)',
  ).hasMatch(master))
    return null;
  final lines = const LineSplitter()
      .convert(master)
      .map((l) => l.trim())
      .toList();
  final choices = <({int width, bool hevc, Uri uri})>[];
  for (var i = 0; i + 1 < lines.length; i++) {
    final line = lines[i];
    if (!line.startsWith('#EXT-X-STREAM-INF:') || lines[i + 1].startsWith('#'))
      continue;
    if (line.contains('VIDEO-RANGE=PQ') || line.contains('VIDEO-RANGE=HLG'))
      continue;
    final size = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
    if (size == null) continue;
    final width = int.parse(size[1]!), height = int.parse(size[2]!);
    if (height == 0 ||
        ((width / height - 1).abs() > .03 &&
            (width / height - .75).abs() > .03))
      continue;
    final uri = base.resolve(lines[i + 1]);
    if (artworkMediaUrl(uri))
      choices.add((
        width: width,
        hevc: line.contains('hvc1') || line.contains('hev1'),
        uri: uri,
      ));
  }
  choices.sort((a, b) {
    final aEnough = a.width >= 720, bEnough = b.width >= 720;
    if (aEnough != bEnough) return aEnough ? -1 : 1;
    if (a.width != b.width)
      return aEnough ? a.width.compareTo(b.width) : b.width.compareTo(a.width);
    return a.hevc == b.hevc
        ? 0
        : a.hevc
        ? -1
        : 1;
  });
  return choices.isEmpty ? null : choices.first.uri;
}

Uri? artworkWholeFile(String media, Uri base) {
  if (!media.contains('#EXT-X-ENDLIST') ||
      RegExp(r'#EXT-X-KEY:(?![^\r\n]*METHOD=NONE)').hasMatch(media))
    return null;
  final resources = <Uri>{};
  var duration = 0.0;
  for (final raw in const LineSplitter().convert(media)) {
    final line = raw.trim();
    if (line.startsWith('#EXTINF:'))
      duration += double.tryParse(line.substring(8).split(',').first) ?? 0;
    String? path;
    if (line.startsWith('#EXT-X-MAP:'))
      path = RegExp('URI="([^"]+)"').firstMatch(line)?[1];
    else if (line.isNotEmpty && !line.startsWith('#'))
      path = line;
    if (path != null) resources.add(base.resolve(path));
  }
  if (duration < .5 || duration > 30 || resources.length != 1) return null;
  final uri = resources.single;
  return artworkMediaUrl(uri) && uri.path.toLowerCase().endsWith('.mp4')
      ? uri
      : null;
}

class AutomaticArtworkResolver {
  AutomaticArtworkResolver({http.Client? client, this.country = 'us'})
    : _client = client ?? http.Client();
  final http.Client _client;
  final String country;
  void close() => _client.close();
  static const maxClipBytes = 20 * 1024 * 1024;

  Future<http.StreamedResponse> _send(
    Uri uri,
    bool Function(Uri) allowed,
    bool Function() current,
  ) async {
    for (var redirects = 0; redirects < 4; redirects++) {
      if (!current()) throw ArtworkLookupCancelled();
      if (!allowed(uri)) throw const FormatException('Unexpected artwork host');
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['User-Agent'] =
          'Mozilla/5.0 (compatible; Musyn artwork lookup)';
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 12));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        await response.stream.listen((_) {}).cancel();
        final target = response.headers['location'];
        if (target == null)
          throw const FormatException('Missing artwork redirect');
        uri = uri.resolve(target);
        continue;
      }
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        if (response.statusCode == 429 || response.statusCode == 403)
          throw ArtworkLookupBusy();
        throw const HttpException('Artwork lookup unavailable');
      }
      return response;
    }
    throw const HttpException('Too many artwork redirects');
  }

  Future<String> _text(
    Uri uri,
    bool Function(Uri) allowed,
    bool Function() current, {
    int limit = 4 * 1024 * 1024,
  }) async {
    final response = await _send(uri, allowed, current);
    final data = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 12),
    )) {
      if (!current()) throw ArtworkLookupCancelled();
      if (data.length + chunk.length > limit)
        throw const FormatException('Artwork metadata too large');
      data.add(chunk);
    }
    return utf8.decode(data.takeBytes());
  }

  Future<ArtworkClip?> find(
    MediaItem item, {
    required bool Function() current,
  }) async {
    if ((item.artist ?? '').trim().isEmpty || item.isLive == true) return null;
    final regions = {
      if (RegExp(r'^[a-z]{2}$').hasMatch(country)) country,
      'us',
    };
    for (final region in regions) {
      final search = Uri.https('itunes.apple.com', '/search', {
        'term': '${item.artist} ${item.title}'.substring(
          0,
          '${item.artist} ${item.title}'.length.clamp(0, 180),
        ),
        'entity': 'song',
        'media': 'music',
        'limit': '12',
        'country': region,
      });
      final decoded = jsonDecode(
        await _text(
          search,
          (u) =>
              u.scheme == 'https' &&
              u.host == 'itunes.apple.com' &&
              u.userInfo.isEmpty &&
              u.port == 443,
          current,
        ),
      );
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! List)
        throw const FormatException('Invalid catalog reply');
      final candidates =
          results
              .whereType<Map>()
              .where((c) => artworkTrackMatches(item, c))
              .toList()
            ..sort((a, b) {
              final album = artworkName(item.album ?? '');
              final exactA =
                  album.isNotEmpty &&
                  artworkName(a['collectionName']?.toString() ?? '') == album;
              final exactB =
                  album.isNotEmpty &&
                  artworkName(b['collectionName']?.toString() ?? '') == album;
              return exactA == exactB
                  ? 0
                  : exactA
                  ? -1
                  : 1;
            });
      final visited = <String>{};
      for (final candidate in candidates) {
        final id = candidate['collectionId']?.toString() ?? '';
        if (!RegExp(r'^\d+$').hasMatch(id) ||
            !visited.add(id) ||
            visited.length > 3)
          continue;
        final pageUri = Uri.https('music.apple.com', '/$region/album/$id');
        final page = await _text(
          pageUri,
          (u) =>
              u.scheme == 'https' &&
              u.host == 'music.apple.com' &&
              u.userInfo.isEmpty &&
              u.port == 443,
          current,
        );
        final address = await compute(_parseAlbumArtwork, (page, id));
        final master = address == null ? null : Uri.parse(address);
        if (master == null) continue;
        final variant = artworkVariant(
          await _text(master, artworkMediaUrl, current, limit: 256 * 1024),
          master,
        );
        if (variant == null) continue;
        final movie = artworkWholeFile(
          await _text(variant, artworkMediaUrl, current, limit: 256 * 1024),
          variant,
        );
        if (movie != null) return ArtworkClip(movie, id);
      }
    }
    return null;
  }

  Future<void> download(
    Uri uri,
    File destination, {
    required bool Function() current,
  }) async {
    final response = await _send(uri, artworkMediaUrl, current);
    if ((response.contentLength ?? 0) > maxClipBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('Artwork video too large');
    }
    final sink = destination.openWrite();
    var size = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 12),
      )) {
        if (!current()) throw ArtworkLookupCancelled();
        size += chunk.length;
        if (size > maxClipBytes)
          throw const FormatException('Artwork video too large');
        sink.add(chunk);
      }
      if (size == 0) throw const FormatException('Empty artwork video');
      await sink.flush();
    } finally {
      await sink.close();
    }
  }
}
