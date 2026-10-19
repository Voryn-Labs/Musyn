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

## 19 October 2026 — audit review and mobile UI parity

See `AUDIT-AND-UI-REVIEW.md` for the supplied reports' claim-by-claim review,
reference commit, implemented changes, and remaining fidelity/device limits.

Local toolchain: Flutter 3.47.7 / Dart 3.13.5 in
`/private/tmp/musified-flutter-sdk`; pub cache `/private/tmp/musified-pub-cache`.

Commands (run from this repository):

```sh
CI=true FLUTTER_SUPPRESS_ANALYTICS=true \
XDG_CONFIG_HOME=/private/tmp/musified-flutter-config \
PUB_CACHE=/private/tmp/musified-pub-cache \
/private/tmp/musified-flutter-sdk/bin/flutter analyze --no-pub

CI=true FLUTTER_SUPPRESS_ANALYTICS=true \
XDG_CONFIG_HOME=/private/tmp/musified-flutter-config \
PUB_CACHE=/private/tmp/musified-pub-cache \
/private/tmp/musified-flutter-sdk/bin/flutter test --no-pub
```

For optional fixture renders, run the UI test with
`--dart-define=MUSYN_RENDER_UI=true test/bitchord_ui_test.dart`.
These renders do not prove native iOS audio, lock-screen reliability, AirPlay,
or frame pacing. Tests mock playback/native services and do not download music.

Final results for this pass:

- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub`: **106 tests passed**.
- UI subset: **14 tests passed**, including a real pointer-held mini-player
  pull, route handoff, inline queue/menu behavior and responsive layouts.
- An isolated Home render also passed after checking the saved preview visually.
- `git diff --check`: passed.
- No full Xcode installation, iOS simulator, connected iPhone or Android reference
  device was available. No native build, real-stream audio or lock-screen signoff
  is claimed.

Working branch: `codex/bitchord-ui-parity`. This pass remains local and reviewable;
it has not been committed or pushed. The earlier reliability push is separate.

## 19 October 2026 — completed flow/recovery continuation

The latest continuation supersedes the earlier 106-test/14-UI-test counts above.
See `UI-FLOW-MAP.md` for registered destinations, real control actions, recovery
states and scope boundaries, and `docs/ui-review/README.md` for previews.

- Complete `flutter test --no-pub`: **149 tests passed**.
- UI coverage: **53 tests**, including failed-load retries, search navigation and
  stale suggestions, chart providers, playlist refresh preserving previous data,
  transfer progress, individual/batch cancellation, collection pin/delete,
  playlist creation inside a folder, settings choices and responsive layouts.
- Renders regenerated with `flutter test --no-pub
  --dart-define=MUSYN_RENDER_UI=true`; render fixtures are local/test data.
- `flutter analyze --no-pub`: **No issues found**.
- `git diff --check`: passed. Import/export reachability traced from `main.dart`:
  no unreachable handwritten app modules after removing twelve obsolete files.
  The import-cycle regression test passes too.
- Small-phone coverage expanded to **320×568 at 1.8× text**, light/dark, across
  Home, Search, Explore, Charts, Library, Playlist, Settings and Downloads.
  Source/download sheets and playlist cancellation were also checked at that
  size. This exposed and fixed clipped Explore labels in addition to the actual
  overflow failures reported earlier.

Final refresh behavior: network refreshes are bounded, failure preserves the
previous playlist, retry calls the loader again, and YouTube refresh bypasses its
track-list cache. Remote zero-track/unavailable responses no longer masquerade
as empty personal playlists; genuinely empty custom playlists remain local.
Folder candidates advertise loading and fall back to available local choices.
Streaming quality clears prepared data while retaining provider pins, and cached
JioSaavn stream metadata must match the requested bitrate.

The suite's intentional failure cases may print diagnostic errors and missing
native logging-plugin messages; the runner finishes successfully. These tests
still do **not** validate AVPlayer, iOS background suspension, real provider
availability or exact BitChord native choreography. Full Xcode, simulator and
physical-device acceptance remain unavailable here. Transfer activity is
session-only; durable OS-managed background downloads were not added.

Changes remain local on `codex/bitchord-ui-parity`; no commit or push was made in
this continuation.

## 19 October 2026 — Musyn 0.1 public release

This section supersedes the earlier local-only status and test counts. The app
is now **Musyn by Voryn Labs**, package `musyn`, iOS bundle
`com.vorynlabs.musyn`, version **0.1.0 (1)**. It starts with a fresh app identity;
no legacy URL schemes or migration are included. Upstream license and author
credits remain in `docs/CREDITS.md`.

- Changes are committed to the public `Voryn-Labs/Musyn` repository on `main`.
- GitHub checks pass on Linux. macOS analysis and the complete **151-test** suite
  also pass. The 53 UI tests use San Francisco on macOS and a licensed Roboto
  fallback on Linux, avoiding Flutter's square Ahem test glyphs. Portable-font
  UI coverage was also verified locally.
- [Native release build 39232222864](https://github.com/Voryn-Labs/Musyn/actions/runs/39232222864)
  succeeded with Flutter 3.47.7 and Xcode on macOS. All native plugins use Swift
  Package Manager; the leftover CocoaPods Podfile was removed to prevent an
  unnecessary, empty Pods integration and manifest-check failure.
- The workflow packaged **Musyn.ipa (11,912,622 bytes)** and generated the public
  installer feeds from its actual Info.plist and size. The 0.1 prerelease includes
  the unsigned IPA, SHA-256 and both source JSON files. The feed is populated only
  after a real build; existing release assets are never silently overwritten.
- The icon, native launch screen and Flutter initialization screen share the new
  folded music mark. Startup has bounded initialization, visible progress and a
  retry state. Distribution identity, launch XML, icon sizes/opacity and feeds
  pass `scripts/verify_branding.py`.
- The Voryn Labs product and privacy pages are deployed, including actual GitHub
  IPA download counts, source copying and installer links. Website registry,
  analytics consistency, links/assets and counter pagination/error fixtures pass.
- Earlier public builds were retired to recoverable GitHub release drafts so the
  public release list starts with Musyn 0.1. Git history and attribution remain.

A successful unsigned native build does not establish real-device playback
reliability. The physical iPhone checklist above remains required for lock-screen
transitions, interruptions, real source switching, offline playback and installer
acceptance. Addons, lossless and durable OS-managed background downloads remain
outside this release's scope.

The studio installer URL is `https://voryn-labs.github.io/source.json`, combining
Cloudified and Musyn. Its **Update iOS source** workflow is manual only: the owner
runs it after publishing new versions. The catalog verifies that both IPA assets
are published, uploaded and match their declared sizes/checksums before replacing
the last working feed. No timer or release-triggered refresh is configured.
The public Musyn IPA was downloaded independently; SHA-256, ZIP integrity, native
arm64 binary, iPhoneOS platform, bundle/version/build and feed size all passed.
