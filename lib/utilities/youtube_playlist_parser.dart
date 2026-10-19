/// Keeps playlist membership separate from recommendations elsewhere on a page.
class YouTubePlaylistParser {
  static Iterable<Map<String, dynamic>> renderers(
    dynamic node,
    String key,
  ) sync* {
    if (node is Map) {
      final match = node[key];
      if (match is Map) yield Map<String, dynamic>.from(match);
      for (final value in node.values) {
        yield* renderers(value, key);
      }
    } else if (node is List) {
      for (final value in node) {
        yield* renderers(value, key);
      }
    }
  }

  static Map<String, dynamic> playlistScope(Map<String, dynamic> response) {
    return {
      'playlistSections': [
        for (final key in [
          'musicPlaylistShelfRenderer',
          'musicPlaylistShelfContinuation',
          'musicShelfContinuation',
          'appendContinuationItemsAction',
        ])
          ...renderers(response, key),
      ],
    };
  }

  static String text(dynamic value) {
    if (value is! Map) return '';
    if (value['simpleText'] is String) return value['simpleText'] as String;
    final runs = value['runs'];
    return runs is List
        ? runs.whereType<Map>().map((run) => run['text'] ?? '').join()
        : '';
  }

  static List<Map<String, dynamic>> charts(Map<String, dynamic> response) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in renderers(response, 'musicTwoRowItemRenderer')) {
      final nav = item['navigationEndpoint'];
      final browse = nav is Map ? nav['browseEndpoint'] : null;
      final id = browse is Map ? browse['browseId']?.toString() : null;
      if (id == null || (!id.startsWith('VL') && !id.startsWith('RDCLAK')))
        continue;
      final playlistId = id.startsWith('VL') ? id.substring(2) : id;
      final title = text(item['title']);
      if (playlistId.isEmpty || title.isEmpty || !seen.add(playlistId))
        continue;
      final thumbnails = renderers(item, 'musicThumbnailRenderer').expand((
        renderer,
      ) {
        final thumbnail = renderer['thumbnail'];
        final values = thumbnail is Map ? thumbnail['thumbnails'] : null;
        return values is List ? values.whereType<Map>() : <Map>[];
      }).toList();
      result.add({
        'ytid': playlistId,
        'title': title,
        'subtitle': text(item['subtitle']),
        'image': thumbnails.isEmpty
            ? ''
            : thumbnails.last['url']?.toString() ?? '',
        'source': 'youtube',
        'catalogOrigin': 'youtube',
        'type': 'chart',
      });
    }
    return result;
  }

  /// Only chart shelves from FEmusic_charts, never radios, artist rankings or
  /// recommendation cards elsewhere in the response. The request uses English.
  static List<Map<String, dynamic>> officialCharts(
    Map<String, dynamic> response, {
    required String country,
  }) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final shelf in renderers(response, 'musicCarouselShelfRenderer')) {
      final header = renderers(
        shelf['header'],
        'musicCarouselShelfBasicHeaderRenderer',
      ).firstOrNull;
      final heading = text(header?['title']).toLowerCase();
      for (final chart in charts({'contents': shelf['contents']})) {
        final title = chart['title'].toString().toLowerCase();
        final group = heading.contains('language')
            ? 'languages'
            : title.contains('video')
            ? 'videos'
            : title.contains('song')
            ? 'songs'
            : title.contains('trending')
            ? 'trending'
            : null;
        if (group == null || !seen.add(chart['ytid'] as String)) continue;
        result.add({...chart, 'chartGroup': group, 'chartCountry': country});
      }
    }
    // Put weekly national charts before daily/trending and language collections.
    int priority(Map chart) {
      if (chart['chartGroup'] == 'songs') return 0;
      if (chart['chartGroup'] == 'videos') {
        return chart['title'].toString().toLowerCase().contains('daily')
            ? 2
            : 1;
      }
      return chart['chartGroup'] == 'trending' ? 3 : 4;
    }

    return [
      for (var rank = 0; rank <= 4; rank++)
        ...result.where((chart) => priority(chart) == rank),
    ];
  }

  static List<Map<String, dynamic>> moodCategories(
    Map<String, dynamic> response,
  ) {
    final categories = <String, Map<String, dynamic>>{};
    for (final item in renderers(response, 'musicNavigationButtonRenderer')) {
      final command = item['clickCommand'] ?? item['navigationEndpoint'];
      final endpoint = command is Map ? command['browseEndpoint'] : null;
      if (endpoint is! Map) continue;
      final id = endpoint['browseId']?.toString();
      final label = text(item['buttonText']).trim();
      if (id == null || id.isEmpty || label.isEmpty) continue;
      final solid = item['solid'];
      final stripe = solid is Map
          ? int.tryParse('${solid['leftStripeColor']}')
          : null;
      categories['$id:${endpoint['params'] ?? ''}'] = {
        'title': label,
        'browseId': id,
        if (endpoint['params'] != null) 'params': endpoint['params'],
        if (stripe != null) 'stripeColor': stripe,
      };
    }
    return categories.values.toList();
  }

  static String? topSongsId(List<Map<String, dynamic>> charts) {
    for (final chart in charts) {
      final title = chart['title']?.toString().toLowerCase() ?? '';
      if (title.contains('song') && !title.contains('video')) {
        return chart['ytid']?.toString();
      }
    }
    return null;
  }
}
