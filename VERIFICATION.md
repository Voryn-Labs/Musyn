# Reliability changes and verification

Developed on `codex/musified-reliability`, based on `2ab0726`. This report records validation of the reliability changes before merging into `main`.

## Implemented

- Playback installs are serialized; superseded URL resolutions and failures cannot restore an older selection. Rapid navigation coalesces taps and stops waiting for stale network requests. Pause/stop intent survives loading, seeking and recovery. Musified owns interruption handling instead of competing with a second just_audio listener. Native source loading occurs before accepting a paused replacement.
- Source switching retains the canonical track and queue occurrence, position and pause state. Resolution keeps the current stream until a replacement URL exists. Explicit source choices are honored. A failed replacement attempts to restore the previous source; stale requests cannot initiate restoration. Global JioSaavn preference no longer has a zero-millisecond lookup timeout. Cross-provider matching preserves Unicode and rejects incompatible live/remix versions.
- Downloads serialize work per track, write to a temporary file, validate length and atomically replace the asset. Cancellation interrupts stalled transfers and removes partial files. Requested quality is passed to stream selection and remembered. Concurrent completions serialize library read/persist/publish updates, including removals. A playlist is marked fully offline only when every track completed and has a playable file.
- Chart cards with preview videos retain their actual playlist identity. Playlist parsing is scoped to playlist shelves and continuations, excluding recommendations elsewhere on the response. Anonymous users can open public Music playlists. Ranked song charts resolve their actual playlist rather than substituting Explore suggestions. If YouTube supplies only video charts for a region, those remain labelled as video charts; the song-trending section is unavailable rather than populated with unrelated results.
- Search categories load independently, with bounded waits and stale-response protection. Catalogue artwork survives provider switches; invalid YouTube IDs no longer produce fabricated thumbnail URLs.
- Source controls show pending/error states and prevent duplicate switch requests. Downloads offer explicit source/quality selection, truthful quality labels, completion/failure counts and cancellation/stopping feedback. Existing lyrics remain intact.

## Checks performed

- Flutter 3.47.7 / Dart 3.13.5: `flutter test --no-pub --exclude-tags network` — **58 passed**.
- `flutter analyze --no-pub` — **0 errors, 0 warnings, 68 informational notices**. The analyzer still exits nonzero for informational lints; this is not a lint-clean checkout. Original checkout: 70 informational notices.
- `git diff --check` — passed.
- Regression cases include delayed/superseded native installs; pause during loading; paused replacement position; rapid skips past an unresolved request; cancellation; truncated transfers preserving the previous asset; concurrent registry writes and persistence failure; duplicate queue occurrences; artwork fallback; chart preview identity/recommendation exclusion; recording-version matching; source-picker pending/error behavior and exact download-quality selection.
- Anonymous live YouTube Music metadata responses were inspected for charts and a chart playlist. The playlist response contained 100 playlist entries in its playlist shelf. This is metadata validation, not a playback or download smoke test.

No package was added. The temporary current-stable SDK refreshed `intl`, `matcher`, `meta`, `test_api` and `vector_math` lockfile versions. The repository's iOS workflow already tracks stable Flutter.

## Device acceptance still required

Full Xcode and an iOS simulator are not installed on this host. Automated tests use a controlled audio player and simulated network streams; they do not exercise AVPlayer, iOS suspension or real provider availability.

1. Build on the target Xcode/iOS version. Lock the phone for at least three natural track transitions, including downloaded → online and online → downloaded. Confirm sound, title, artwork and elapsed time match.
2. Tap Next/Previous rapidly during slow resolution; pause and stop while loading; seek repeatedly from Control Center. Confirm no old track starts and no delayed operation undoes Pause.
3. Switch each available source while playing and paused; repeat during an unavailable source and a network change. Confirm queue occurrence, position, artwork and pause intent remain correct. Test a call/Siri interruption and Pause during the interruption.
4. Download a song and a playlist at each offered quality. Cancel during an active transfer, retry, interrupt the network, and repeat a download of an existing track. Relaunch offline and play every completed entry. Verify partial playlists remain partial.
5. Open each chart and play its first, middle and last entries in displayed order. Confirm recommendations do not enter the chart queue. Exercise anonymous and signed-in browsing and unavailable regional song charts.
6. Check the source and download sheets on small/large iPhones, light/dark mode, larger text and reduced motion. Review the larger player/download visual redesign after these functional checks.

Addon integration and lossless are outside the agreed scope. Durable OS-managed background download jobs and a wholesale player redesign are not implemented by this change; this pass fixes the existing app's coordination and transfer paths.
