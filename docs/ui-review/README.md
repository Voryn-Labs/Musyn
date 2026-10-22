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

The optional render command is documented in `../../VERIFICATION.md`.
The implementation/reference audit and outstanding fidelity limits are in
`../../AUDIT-AND-UI-REVIEW.md`. Device comparison is still required for exact
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

## 0.1.5 screenshot follow-up

- [iPhone shell — Home](iphone-home-dark.png), [Explore](iphone-explore-dark.png), [Library](iphone-library-dark.png), [Search](iphone-search-dark.png): 402×874 with 59-point top and 34-point bottom safe areas.
- [Compact lyrics controls](lyrics-dark.png).
- Player, charts, source/download sheets and accessibility renders were regenerated for this change. Fixture artwork remains a placeholder.
- [Fixes and verification limits](../0.1.5-fixes.md).

## 0.1.7 follow-up

- Native [Settings](settings-dark.png), [Downloads](downloads-dark.png) and [track actions](track-menu-dark.png), with an integrated mini-player and direct player download control.
- Walkthrough: [welcome](walkthrough-welcome.png), [sources](walkthrough-sources.png), [gestures](walkthrough-ready.png); corresponding `*-small.png` files exercise large text on a small viewport and scrollable content.
- Version 0.2.0 removes simulated continuous sleeve movement and generated lock-screen video loops. The reference animates the illustration itself; current providers supply still artwork. Covers remain still, while track gestures and sheet transitions remain interactive.
- [Fixes and verification limits](../PLAYER_AND_UI_FIXES_0.1.7.md).

## 0.1.8 follow-up

- Settings now has individual Playback, Downloads, Appearance, YouTube Music and Storage/diagnostics destinations; `settings-*-detail.png` and `settings-*-large-text.png` exercise their real navigation.
- [Splash](splash-dark.png) and [slow-start status](splash-slow-dark.png) retain stationary branding.
- [Device-log findings and verification limits](../DEVICE_LOG_AUDIT_0.1.8.md).

## 0.3 public release

- New provider setup, Support, Privacy and Terms renders accompany the updated Settings, download and walkthrough screens. These are headless Flutter renders using fictional content.
- Optional iOS 26 glass and local video artwork use native platform views. They require physical-device acceptance; these still renders do not establish motion quality or lock-screen behavior. Clips are imported by the user; still covers remain the fallback.

## 0.3.2 glass correction

`iphone-*-glass-dark.png` exercise compact native-view bounds using a mocked platform surface; the real material requires a device check. `glass-selection-mid-transition.png` and `playback-pause-mid-transition.png` capture actual intermediate Flutter animation frames. The player renders now show transport controls directly over the background. [Scope and verification limits](../GLASS_FIXES_0.3.2.md).

## Sing Along status

Older `sing-along-dark.png` previews show the experimental stage. Sing Along is
now marked upcoming; these older previews are not evidence of released fast
vocal reduction. Current preview: [Sing Along — coming soon](sing-along-upcoming-dark.png).
