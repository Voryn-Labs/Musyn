# Audit and BitChord UI review — 19 October 2026

Reviewed the supplied `AUDIT_FIXES_DOCUMENTATION.md` and
`BITCHORD_UI_REWRITE_COMPLETION_REPORT.md` against commits `b30f45f`, `d31c650`,
`27b9377`, `6e53d42`, and the resulting checkout. The reports contain useful
findings, but neither establishes that every playback bug is fixed or that the
UI matches BitChord exactly.

## Verdict on the nine reported fixes

| Claim | What the code actually showed | Correction in this branch |
| --- | --- | --- |
| C1: source validator | Real provider-validation bypass. Fixed in `b30f45f`, then reverted by the UI rewrite. The replacement test explicitly accepted contradictory URL/provider pairs. | Restore strict provider validation. A prepared URL carries its own provider/headers so retaining a warm URL does not require accepting contradictory metadata. |
| C2: auto-mode scrubbing | Partial fix: the added branch required `preferred == auto` and a resolved provider, but `preferredStreamSourceForSong` returns that resolved provider first. That branch was unreachable. | Validate both prepared and cached URLs against their descriptors and explicit source selection. Drop incompatible data together. |
| C3: lock-screen skips | The loading-path change is real. The report's fixed 2–3 second rule, claimed extension of background time, and comparison with Apple Music/Spotify internals were not demonstrated. `setActive(true)` alone does not prove reliable background playback. | Keep best-effort activation; check interruption, pause and transition ownership after awaiting the session. Physical iOS verification remains required. |
| H1: recommendations | The concurrency guard is useful. However, timed-out requests could still mutate the global next-recommendation variable, and old results could reach a replaced queue. | Return request-local results; check selection revision, offline state and autoplay preference before insertion. Late results no longer publish into shared global state. |
| H2: temporary source pin | Real issue. Cleanup after an await could still miss exceptional/stale paths or remove a newer pin. | Resolve fallback with a cloned song. The queue entry never receives the temporary forced source. |
| H3: completion retry | A failed advance can leave playback idle. An unconditional delayed retry can also override a pause or a replacement selection. | Retry only while playback is wanted, the queue occurrence/selection still matches, and no source change/load is in flight. |
| H4: preload clone | Valid isolation fix. Publishing only the URL discarded resolver metadata needed by the eventual install, including provider and User-Agent. | Cache URL and resolver descriptor together; apply them together only when consumed. Preserve metadata for another occurrence of the track too. |
| M1: recommendations always YouTube | The change covered the related-video fallback, but not the preferred Music radio path. Deleting catalogue provenance is also unnecessary. | Mark both recommendation paths consistently; preserve catalogue identity while allowing global playback preference to apply. |
| M5: haptic future | Lint cleanup, not evidence of an audio bug. | Retained. |

The checkout initially passed **84 tests** and had a clean analyzer. The report's
85-test result was not reproduced on that checkout. Passing unit/widget tests
does not constitute a physical iOS lock-screen playback test.

## UI findings and changes

The previous rewrite was an Apple Music/BitChord mixture. Its own Home heading
was still `Musified`, despite the report describing `Listen Now`. It used
Home/Search/Library/Settings tabs, while the current Android reference uses
Home/Explore/Library/Search. It used Apple Red as the main accent, while the
reference's current primary color is white in dark mode and black in light mode.
Some queue/player reference files in the report came from the desktop UI.
The claimed 16:9 hero and 140-point shelves also differ from this reference: its
current shared constants use a 0.92 hero aspect ratio, 70% width capped at 320,
and 150-point shelf cards. Those dimensions are now used in the relevant feed
and library cards.

Changes made here:

- Four reference tabs, independent navigation stacks, account/settings above the
  tabs, and a draggable selection capsule. Search activation clears and focuses
  the field. Playlist/folder/artist routes also work inside Explore.
- Listen now header, account entry, shared monochrome controls, readable contrast
  in both themes, 20-point page gutters, and the reference's larger heading type.
- Explore loads actual server-defined mood/genre browse IDs and params. Category
  cards preserve server stripe colors and deduplicate shortcuts. Selecting one
  opens playlist destinations rather than issuing a generic search. Actual
  chart playlist shelves remain on Home.
- Library keeps device/history links and presents Liked Music as a collection
  card, alongside the create-playlist tile and existing user collections.
- Fixed search field/filter region; typing suppresses stale result sections.
  Removed invented chart/genre search shortcuts from the empty search page.
- Root player sheet with finger-driven opening/dismissal, spring settling,
  horizontal skip gestures, cover-to-queue gesture, inline queue/lyrics panes,
  large transport controls, volume row and central action capsule. Existing
  lyric fetching, parsing and synchronization remain in use.
- Source/quality and download controls retain their real Musified functions.
  Artist navigation, favorites, queue manipulation and sleep timer remain
  accessible. Unsupported party/addon features were not represented as working.
- Rounded, aligned track action drawer. Menu downloads now use the source/quality
  picker rather than bypassing it.
- File-aware artwork in player, drawer, Home, Search and Library. The rewrite had
  sent local file URIs to a network-only widget.
- Corrected two actual Home layout failures exposed by populated-screen tests:
  an unconstrained nested recents header and a three-card loading skeleton that
  overflowed a phone by 112 pixels. Recents list mode now uses four-track columns.
- Changing the default provider now clears resolved hints and prepared URLs as
  well as explicit pins. Previously those hints could defeat the new preference.
  The chosen default also applies to YouTube-catalogue tracks. Corrected settings
  that misleadingly described 320 kbps AAC as lossless or a studio master.
- Autoplay status follows the real setting; the queue no longer claims autoplay
  is active when it is disabled. Reduced Motion is respected for the new sheet.

## Verification and limits

The reproducible commands and test results are recorded in `VERIFICATION.md`.
`test/bitchord_ui_test.dart` exercises tab selection, player-sheet settling,
mini-player skip/expansion, populated main screens, small phones, landscape,
light/dark themes and large text. Fixture renders are in `docs/ui-review/`.
They use sample titles and placeholder artwork; they are **headless Flutter
renders, not device screenshots**. System SF fonts are read locally for renders
when available; no Apple font files are bundled in the repository.

This is a substantial parity pass, **not a verified pixel-for-pixel copy of every
BitChord screen and animation**. A running BitChord Android reference and a full
Xcode simulator or iPhone are unavailable in this environment. The new volume
slider controls Musified's player volume; it is not a native system-volume or
AirPlay picker. The capsule deliberately keeps source/download controls rather
than presenting unsupported output/party actions. Full-player artwork docking,
queue panel choreography, and the remaining settings/detail-screen differences
still need direct reference comparison. No addon integration or lossless work
was introduced.

## Reference and attribution

Design reference: [BitChord](https://github.com/kushagrasinghx/BitChord), Android
mobile/shared Compose source at `edc1e6f36febf71a118e649411d2fc21b70ead45`.
Inspected `Theme.kt`, `FloatingBottomBar.kt`, `MiniPlayer.kt`, mobile
`MainActivity.kt`, `HomeScreen.kt`, `ExploreScreen.kt`, `LibraryScreen.kt`,
`SearchScreen.kt`, `NowPlayingScreen.kt`, `PlayerControls.kt`, and the mood parser.
The Flutter implementation is adapted for Musified's existing playback services.
Both repositories declare GPL-3.0. No BitChord addon modules or bundled Apple
fonts were copied.

## Continuation: functional screens and recovery

The follow-up pass is mapped in `UI-FLOW-MAP.md`. It adds a dedicated Downloads
manager and provider-specific Charts page, restores pinned/saved/folder access,
and distinguishes empty, loading and failed data across Search, Explore,
collections and artists. Unknown/deleted destinations recover to real app pages.
The former Most Played link now ranks listening counts and plays the visible
order. Search suggestions are guarded against later submitted/replaced queries.

New tests exposed and drove fixes for the artist retry assertion, narrow/large
text overflows in Settings and Library, and source-error visibility. Playlist
creation validates before dismissal, reports failures, and honors the originating
folder. Collection menus support pinning and confirmed custom deletion.
Settings has explicit provider and streaming-quality choices; quality changes
preserve source pins. Download sheets have contrasting controls and scrollable
layouts. Storage/history controls update their in-memory state as well as Hive.
Twelve now-unused handwritten files were removed after import reachability and
test-reference checks, including the superseded player widgets.

These changes make the supported flows functional and reviewable. They do not
remove the native/device or exact-reference-parity limits described above.

Final continuation verification: **149 total tests / 53 UI tests**, clean analyzer
and clean whitespace check. Visual review also caught clipped large-text Explore
labels that layout exceptions alone did not detect; the grid now adapts to one
column. The last functional fix replaced the obsolete playlist refresh path:
chart refreshes now use their real source, YouTube refresh bypasses cached tracks,
and a failed refresh retains the visible list with retry. `VERIFICATION.md`
records the exact scope and native testing limits.
