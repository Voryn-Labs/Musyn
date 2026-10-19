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
