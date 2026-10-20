# Musyn 0.2.0 — rapid skips and first playback

Reviewed the supplied October 20 13:10–13:14 device log and the playable landscape reference. Private device logs are not copied into the public repository.

## What the log demonstrates

- First request: 13:11:00.203; stream installation starts 13:11:04.871; native player ready 13:11:08.175. About **7.97 seconds** overall: 1.33 seconds of JioSaavn searching despite `target=youtube`, 3.34 seconds resolving YouTube, then 3.30 seconds of native loading. App/library startup is separately logged at 44 ms; it does not explain this tap-to-play delay.
- Warm Saavn skip installations generally take 0.6–0.8 seconds in this trace. Rapid replacements can supersede an earlier load correctly. The trace contains no artwork completion diagnostics, so it does **not** prove a specific network error caused missing covers.
- The reference cover remains stationary while the illustration inside it changes. Floating a still cover is not the same effect. The user's selected behavior is still artwork when a genuine animated asset is unavailable.

## Changes

1. **Background-safe square covers.** Previously preparing a cover required `dart:ui` codec/raster work. Flutter's rendering surface may be suspended while background audio continues. On iOS, square conversion now uses ImageIO and Core Graphics on a utility queue. The local PNG goes directly to audio_service's native file-artwork path. This removes a background renderer dependency; it is not a claim of physical-device reproduction.
2. **Warm covers and retain completed results.** Prepare the next three covers alongside audio warming, including offline queue entries. Coalesce pending jobs per original URI and retain a bounded 40-entry map. Repeated metadata/duration publications reuse a completed cover. Existing exact-entry/original-URI guards reject stale results. A new cache revision replaces the previous raster-prepared covers. Failed or tiny max-resolution assets fall back to the known thumbnail.
3. **Share in-flight stream lookup.** A tap on a warming track reuses the same lookup for compatible provider, quality and catalogue identity. Each caller keeps its own cancellation and queue identity. A superseded warmup cannot cancel a joined foreground request or publish stale playback. Failed requests are released for retry.
4. **First-selection warming.** Warm one recent track during launch, without queue selection, a native audio item, or autoplay. Offline tracks only warm their cover. This helps that likely selection; arbitrary cold selections still require network work.
5. **Remove avoidable source search.** A track that resolves through YouTube no longer first performs a JioSaavn search just because the global preference is JioSaavn. Explicit per-track source pins remain honored. Explicit YouTube selection bypasses Saavn lookup even for a Saavn catalogue entry, then resolves its matching YouTube ID.
6. **Buffer preference.** Reduce preferred forward buffering from five seconds to one. This is a latency/buffering tradeoff; the native player still requires media data before readiness, and slower networks can rebuffer. Device measurements are needed before reporting a speed improvement.
7. **Still artwork.** Remove the continuous simulated sleeve movement and the synthetic native eight-second movie encoder. Current providers supply still images. Restore upstream audio_service 0.18.19 instead of retaining a fork solely for generated animation. Existing local favorite commands remain supported. No unconfigured animated-artwork source or empty UI control is added.
8. **Diagnostics.** Log cover availability/preparation time, resolution time and native installation time independently, for comparison on the next device run.

## Validation

- The complete Flutter suite passes **204 tests**. Static analysis and branding checks pass.
- `python3 scripts/test_native_artwork.py` compiles the actual production crop on macOS and tests video letterbox removal at edges and center, square dimensions, minimum-width placeholder rejection, and invalid-data handling. This also runs in macOS release CI.
- Controlled-player tests verify delayed previous-track covers cannot replace the new cover, repeated publications share preparation, and duration refreshes retain the completed cover. Resolver tests cover concurrent warmup/tap, independent cancellation, incompatible provider/quality, and retry after failure.
- Landscape renders at normal and large text were regenerated and visually reviewed using fictional fixture content. This host has no iOS Simulator/full Xcode, so no simulator recording or physical-iPhone timing/lock-screen acceptance is claimed.

## Remaining device checks

Cold network resolution cannot be instantaneous. Compare the new timing fields on a fresh selection, a warmed selection, rapid skips while locked, and weak-network playback. The earlier approximately doubled native duration for some YouTube streams remains an independent observation; this release does not claim to repair a decoder issue.
