import 'package:flutter_test/flutter_test.dart';
import 'package:musified/utilities/youtube_playlist_parser.dart';

void main() {
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
}
