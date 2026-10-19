import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/utilities/track_matcher.dart';

void main() {
  test('source substitution preserves studio/live/remix recording choices', () {
    expect(TrackMatcher.titlesMatch('Example', 'Example (Live)'), isFalse);
    expect(TrackMatcher.titlesMatch('Example (Remix)', 'Example'), isFalse);
    expect(
      TrackMatcher.titlesMatch('Example (Live)', 'Example - Live'),
      isTrue,
    );
    expect(
      TrackMatcher.titlesMatch('Live Forever', 'Live Forever (Official Audio)'),
      isTrue,
    );
  });

  test('matching preserves non-Latin titles instead of stripping them', () {
    expect(
      TrackMatcher.titlesMatch('तुम ही हो', 'तुम ही हो (Official Audio)'),
      isTrue,
    );
    expect(TrackMatcher.titlesMatch('तुम ही हो', 'पहला नशा'), isFalse);
  });

  test('artists sharing a surname do not match a different recording', () {
    expect(
      TrackMatcher.isExactMatch(
        titleA: 'Example',
        artistA: 'Arijit Singh',
        durationA: 180,
        titleB: 'Example',
        artistB: 'Jagjit Singh',
        durationB: 180,
      ),
      isFalse,
    );
  });
}
