# UI flow and recovery map

Updated 19 October 2026. Implemented in the Musyn Flutter app; addon integration
and lossless playback remain outside scope. This maps supported screens to real
services and recovery actions. It does not certify native iOS playback or exact
BitChord visual/motion parity.

## Main navigation

The four tabs are Home, Explore, Library and Search, with independent navigation
stacks. Account/settings opens `/settings`; diagnostics is `/settings/logs`.
Mini-player tap/pull opens the root player, horizontal swipes skip tracks, and
player dismissal returns to the underlying screen. Active downloads add a direct
entry beside the account control.

| Screen / destination | Real content and actions | Loading, empty, failure or offline behavior |
| --- | --- | --- |
| Home `/home` | Trending tracks, recents, favorites, actual chart playlists, saved collections and ranked most-played songs. Song taps replace the queue with that shelf's list. Collection taps open their IDs. | Bounded feed loading; partial failures retain available shelves and expose Refresh music. Empty feed exposes Search, moods/genres and charts. Offline Home shows downloaded songs. |
| Explore `/explore` | Server-provided moods/genres; each category preserves its browse ID and params. | Loading message, bounded request, retry and Charts destination. Offline state links to downloads. Invalid category entries are filtered. |
| Category `/explore/category?id=…&params=…&title=…` | Fetches that category's real collections, then opens album/playlist IDs. Query parameters restore the destination when router `extra` is absent. | Failed/empty categories offer retry and a title-based search. Large text uses a single-column grid to avoid clipped labels. Incomplete destinations use the failure state. |
| Charts `/<tab>/charts` | Actual YouTube Music and JioSaavn chart playlists, separate provider selector and cached snapshots. | Providers load/fail independently. Retry retains any cached lists. Offline state links to saved music. Disabling JioSaavn returns the selector to YouTube. |
| Search `/search?q=…` | Songs, artists and playlists; suggestions, removable search history, typed filters and a top-result play action. Opening a different query updates the existing page. | Idle discovery links; typing guidance rather than false “no results”; section failures/retry; distinct no-match/filter-empty states. Late suggestions cannot replace submitted results. Offline Search exposes Go online and Downloads. |
| Library `/library` | Downloads, recents, ranked Most Played, Liked Music, pinned collections, folders, custom playlists, saved/offline collections and signed-in YouTube collections. | Empty library still has working create, discover and account actions. Pinned/saved/folder sections remain reachable and listen to their backing notifiers. |
| Downloads `/<tab>/downloads` | Current track/batch transfers; byte progress where length is known, received MB otherwise; track cancellation, batch cancellation, failed/cancelled retry, clear-finished, saved-track search/sort/play. | Empty downloads explains how to save music and offers Search or Go online. Filter-empty offers Clear filter. Batch-owned track rows cannot cancel a shared playlist token. |
| User collection `/library/userSongs/{liked,offline,recents,mostPlayed}` | The selected saved list; Most Played sorts by actual listening count, preserving recent tie order. Playback uses the same visible ordering. | Descriptive empty state and Find music. Unknown collection names offer Library recovery. |
| Collection `/<tab>/playlist/:id` and album `/<tab>/album/:id` | Cover/title, real track list, play/shuffle, sort/filter, favorite, add, refresh/download and custom edit/share actions as applicable. Grid/card long-press opens collection actions. | Initial loading and refresh are bounded. Refresh bypasses the YouTube track cache, handles Saavn charts, prevents duplicate requests and preserves the old list on failure. Remote failure differs from a genuinely empty local playlist. Retry, clear-filter and discovery actions replace dead ends. Empty custom collections do not trigger a remote lookup. |
| Artist `/<tab>/artist/:id`, full catalog `/songs` | Profile, top songs, releases, related artists, catalog play/shuffle/add/download and All songs. | Bounded profile/catalog requests; failed profile offers retry and name search. Failed catalog play gives feedback and can be retried. |
| Folder `/<tab>/folder/:id/:name` | Stored playlist rows plus add/rename/delete/remove operations. | Empty folder offers Add playlist; if no candidate exists, creation saves the new custom playlist into that folder. Deleted folders offer Library recovery. |
| Unknown link | Friendly “page unavailable” screen. | Home and Library recovery; no raw router error page. |

`<tab>` is `home`, `explore`, `library` or `search`; collection IDs and folder
names are encoded as URL components. Charts, downloads, playlists, artists,
albums and folders have registered routes in each tab.

## Player, menus and settings

| Control | Backing action / behavior |
| --- | --- |
| Transport, seek, queue and autoplay | Existing playback controller and queue. Queue modes reflect the actual autoplay preference; play/skip/pause coordination fixes from the preceding audit remain in place. |
| Source capsule | Source picker calls the playback controller. Shows pending state, blocks duplicate requests, retains retry after failure, and scrolls the error into view. A missing local file disables Downloaded; disabled JioSaavn is explained. |
| Download action | Explicit provider and quality picker calls the atomic offline transfer service. Options stay reachable on a small phone with large text. Activity and completed files appear in Downloads. |
| Song drawer | Real play-next, queue, like, playlist, artist, download and sleep actions where applicable. Unsupported addon/party/output features are not represented as working controls. |
| Collection menu | Pin/unpin, favorites, offline removal, and contextual deletion where available. Custom deletion asks for confirmation. A reached pin limit gives feedback. Folder actions live inside the folder page. |
| Appearance | System/light/dark and OLED preference. Selected controls have contrasting foreground text in both themes. |
| Default provider | Explicit Auto/YouTube Music/JioSaavn choice; persists and invalidates old source/preload selections for upcoming tracks. |
| Streaming quality | Existing YouTube Highest/Balanced/Data saver selection and JioSaavn AAC 160/320 kbps preference, persisted to settings. Prepared streams are cleared while source pins are kept; current playback continues. Cached JioSaavn metadata must match the configured bitrate. |
| Repair YouTube playback | Existing client configuration sync and stream-cache invalidation, with user-facing progress/result copy. |
| Storage/history | Cache action reports success/failure, invalidates prepared audio and retains downloaded files. History clear updates both storage and in-memory search/recents. |
| Account and diagnostics | Existing sign-in/out, library synchronization and diagnostic log controls. Version is an information row without a navigation chevron. |

Transfer activity is session-only and bounded to 30 finished jobs; saved files
and offline membership persist through the existing registry. Restarting the app
does not resume an OS-managed download queue. Batch progress uses the existing
playlist service and cancellation token, not a second download engine.

## Code cleanup and evidence

Removed twelve unused legacy files after tracing imports/exports from `main.dart`
and checking tests for references: the old player controls/artwork/lyrics modal,
its unused backdrop/empty state, old marquees, flip card, glass container,
static browse categories, and superseded empty-playlist widget. The active lyrics
parser, synchronized view, theme and fetching remain in use. The dependency graph
has no remaining unreachable handwritten app modules and no import cycles.

See [UI previews](docs/ui-review/README.md) for headless renders. Automated coverage
includes navigation, retry, cancellation, visible queue ordering, creation,
pin/delete, settings persistence, light/dark themes, 320×568 at 1.8× text, and
player landscape/drag behavior. Render fixtures use sample titles and placeholder
artwork; they are not live-stream or device screenshots.

Physical iOS testing remains necessary for AVPlayer, lock-screen transitions,
interruptions, real provider/download availability and native gesture frame
pacing. Exact BitChord settings/detail layout and player choreography still need
a running reference comparison; this work does not claim pixel-for-pixel parity.
