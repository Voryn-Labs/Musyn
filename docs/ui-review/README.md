# UI review renders

These PNGs are headless Flutter widget renders from `test/bitchord_ui_test.dart`,
using fictional sample tracks, placeholder artwork and injected catalogue data.
They are not screenshots of streamed audio or a physical iOS device.

- [Home](home-dark.png)
- [Explore](explore-dark.png)
- [Library](library-dark.png)
- [Search](search-dark.png)
- [Player — dark](player-dark.png)
- [Player — light](player-light.png)
- [Player — small phone](player-small.png)
- [Player — large text](player-large-text.png)
- [Player — landscape](player-landscape.png)
- [Track menu](track-menu-dark.png)

Device comparison is still required for exact
BitChord motion, artwork docking, native audio controls and remaining detail and
settings-screen differences.

## Continuation renders

- [Search results](search-results-dark.png)
- [Charts](charts-dark.png)
- [Downloads and transfer progress](downloads-dark.png)
- [Playlist](playlist-dark.png), [artist](artist-dark.png), [folder](folder-dark.png)
- [Settings — dark](settings-dark.png), [light](settings-light.png)
- [Quality settings — dark](quality-settings-dark.png), [light](quality-settings-light.png)
- [Source retry — small phone, large text](source-sheet-small-dark.png)
- [Download picker — small dark](download-sheet-small-dark.png), [small light](download-sheet-small-light.png)
- [Home with failed feed](home-error-dark.png)

The `*-small-large-text-*` renders cover Home, Search, Charts, Settings, Downloads, Playlist, Library
and Explore at 320×568 and 1.8× text in both themes. These are scrolled/tested
layouts, not claims that all content fits above the fold. Review the route and
action inventory in `../../UI-FLOW-MAP.md`.

## 0.3 public release

- New provider setup, Support, Privacy and Terms renders accompany the updated Settings, download and walkthrough screens. These are headless Flutter renders using fictional content.
- Optional iOS 26 glass and local video artwork use native platform views. They require physical-device acceptance; these still renders do not establish motion quality or lock-screen behavior. Clips are imported by the user; still covers remain the fallback.

## 0.3.2 glass correction

`iphone-*-glass-dark.png` exercise compact native-view bounds using a mocked platform surface; the real material requires a device check. `glass-selection-mid-transition.png` and `playback-pause-mid-transition.png` capture actual intermediate Flutter animation frames. The player renders now show transport controls directly over the background.

## Sing Along status

Older `sing-along-dark.png` previews show the experimental stage. Sing Along is
now marked upcoming; these older previews are not evidence of released fast
vocal reduction. Current preview: [Sing Along — coming soon](sing-along-upcoming-dark.png).
