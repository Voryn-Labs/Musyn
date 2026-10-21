# Lock screen and player — 0.3.4

The user reported no elapsed/remaining time in 0.3.3, primarily for JioSaavn songs, and no animated artwork. A phone/iOS runtime reproduction was unavailable on the development host; its Xcode installation contains only Command Line Tools. This update fixes identified metadata weaknesses and adds diagnostics; it does not claim that compilation proves the device symptom is resolved.

## Timing

Decimal catalogue durations previously fell through integer parsing to unknown/zero. Resolved-source metadata could replace a previously known duration. The Dart publisher now retains a known same-entry duration and parses decimal seconds. JioSaavn catalogue length wins over inconsistent HE-AAC player duration. The native plugin independently retains a positive duration for the same entry, resets across entries, and recovers catalogue seconds.

The native bridge advances elapsed time to publication, freezes effective rate when playback is not ready, and retains normal default rate while paused. Artwork and lyric enrichment derive from one timestamped canonical snapshot; each rewrite advances that snapshot instead of repeatedly publishing an old elapsed value. Stop clears the snapshot and lyric timer. The plugin patch is documented in `packages/audio_service/MUSYN_PATCH.md`.

## Artwork

The previous bridge only offered the source clip’s original ratio. A platform advertising only the other supported ratio ignored it. The new adapter selects a supported ratio and exports a cropped variant of the real video when required. It does not invent artwork motion. Preparation waits for system capability discovery, is guarded against stale selections and is bounded after failures. Derived cache files retain the cache-clear/pinning protections.

An actual automatically downloaded square cover was converted using the production adapter to a silent **720 × 960** clip and accepted by the production AVFoundation validator. The local sandbox could not complete the video export; the authorized test completed with access to macOS video services. No downloaded artwork is committed.

## Lyrics and UI

Optional lock-screen lyrics use the current timed line in the artist row, a behavior studied in Taurus. Independent implementation uses public MediaPlayer APIs; no tweak code was copied. Native timing keeps the feature independent of Flutter UI frame delivery. Lines are sent once per selection, request results are guarded across skips/opt-out, plain lyrics receive no invented timing, and the original artist is retained/restored when appropriate.

Sing-along is a focused line-timed lyric stage. It retains original vocals. It is not Apple Music Sing vocal separation; that would require a separate processing engine/model and audible-latency validation. Landscape now balances artwork/credits/controls with lyrics and provides a large-text scrolling fallback. Full-player More uses a native anchored UIMenu on iOS rather than a large action sheet. Downloads remain outside the menu.

## Verification

Local validation: **249 tests passed** (including rendered UI flows), Flutter analysis is clean, branding and public-release credential guards pass, and native timeline fixtures pass against the actual production Objective-C helper functions. Swift source syntax parses. The production AVFoundation variant exporter and validator accepted the converted real clip. Native iOS compilation and published artifact details are recorded after the release build. Automated UI previews show fixture content, not physical-device native menu or lock-screen acceptance.
