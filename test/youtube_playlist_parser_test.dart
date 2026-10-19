import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/utilities/youtube_playlist_parser.dart';

void main() {
  test(
    'live India chart shelves stay separate from songs and artist rankings',
    () {
      final response = Map<String, dynamic>.from(
        jsonDecode(
              File(
                'test/fixtures/youtube_charts_india.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      final charts = YouTubePlaylistParser.officialCharts(
        response,
        country: 'IN',
      );
      expect(charts, hasLength(10));
      expect(charts.where((c) => c['chartGroup'] == 'videos'), hasLength(2));
      expect(charts.where((c) => c['chartGroup'] == 'languages'), hasLength(7));
      expect(charts.first['title'], 'Top 100 Music Videos India');
      expect(charts.every((c) => c['chartCountry'] == 'IN'), isTrue);
      expect(YouTubePlaylistParser.topSongsId(charts), isNull);
      expect(
        charts.any((c) => c['title'].toString().contains('Alka')),
        isFalse,
      );
    },
  );

  test('chart playlist with a preview video remains a playlist', () {
    final response = <String, dynamic>{
      'items': [
        {
          'musicTwoRowItemRenderer': {
            'title': {
              'runs': [
                {'text': 'Top 100 Songs'},
              ],
            },
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'VLPLchart'},
            },
            'overlay': {
              'musicItemThumbnailOverlayRenderer': {
                'content': {
                  'musicPlayButtonRenderer': {
                    'playNavigationEndpoint': {
                      'watchEndpoint': {'videoId': 'preview1234'},
                    },
                  },
                },
              },
            },
          },
        },
        {
          'musicTwoRowItemRenderer': {
            'title': {
              'runs': [
                {'text': 'Unrelated video'},
              ],
            },
            'navigationEndpoint': {
              'watchEndpoint': {'videoId': 'suggestion1'},
            },
          },
        },
      ],
    };
    final charts = YouTubePlaylistParser.charts(response);
    expect(charts.map((chart) => chart['ytid']), ['PLchart']);
    expect(YouTubePlaylistParser.topSongsId(charts), 'PLchart');
  });

  test('playlist parsing excludes songs from recommendation carousels', () {
    final response = <String, dynamic>{
      'contents': {
        'musicPlaylistShelfRenderer': {
          'contents': [
            {
              'musicResponsiveListItemRenderer': {'id': 'rank-one'},
            },
            {
              'musicResponsiveListItemRenderer': {'id': 'rank-two'},
            },
          ],
        },
      },
      'suggestions': {
        'musicCarouselShelfRenderer': {
          'contents': [
            {
              'musicResponsiveListItemRenderer': {'id': 'unrelated'},
            },
          ],
        },
      },
    };
    final scope = YouTubePlaylistParser.playlistScope(response);
    expect(
      YouTubePlaylistParser.renderers(
        scope,
        'musicResponsiveListItemRenderer',
      ).map((item) => item['id']),
      ['rank-one', 'rank-two'],
    );
  });

  test('video or artist charts are never substituted for a songs chart', () {
    expect(
      YouTubePlaylistParser.topSongsId([
        {'ytid': 'video', 'title': 'Top Music Videos'},
        {'ytid': 'artist', 'title': 'Top Artists'},
      ]),
      isNull,
    );
  });
  test(
    'mood destinations retain params and deduplicate personalised shortcuts',
    () {
      Map button(String key, String params) => {
        'musicNavigationButtonRenderer': {
          'buttonText': {
            'runs': [
              {'text': 'Chill'},
            ],
          },
          key: {
            'browseEndpoint': {
              'browseId': 'FEmusic_moods_and_genres_category',
              'params': params,
            },
          },
          'solid': {'leftStripeColor': '4283842435'},
        },
      };
      final items = YouTubePlaylistParser.moodCategories({
        'contents': [
          button('clickCommand', 'chill'),
          button('navigationEndpoint', 'chill'),
          button('clickCommand', 'focus'),
        ],
      });
      expect(items.length, 2);
      expect(items.map((item) => item['params']), ['chill', 'focus']);
      expect(items.first['stripeColor'], 4283842435);
    },
  );
}
