# Musyn device log audit — October 20, 2026

Reviewed the supplied 02:02–02:10 device log and Liked Music error screenshot. The private device log and screenshot are not copied into the public repository.

| Finding | Evidence and cause | Change |
| --- | --- | --- |
| Liked Music cannot open | Five repeated public playlist requests for `VLLM` return 404. That is a private Music browse ID, not a public YouTube playlist URL. | Handle the collection through authenticated `VLLM` browse directly, including a valid empty collection. Never scrape it anonymously. Offer account settings when it cannot load. |
| Wrong likes feed | The implementation used `FEmusic_liked_videos`, which is the library-songs feed. | Use `VLLM` for liked songs; verify recognizable playlist content before accepting a successful response. [Upstream reference](https://github.com/sigma67/ytmusicapi/blob/main/ytmusicapi/mixins/playlists.py). |
| Local favorites can disappear | `syncLikedSongs` replaced the entire local favorites list. Failed fetches also returned an empty list, indistinguishable from an empty account. | Merge remote favorites with durable local intent. Keep non-YouTube favorites local. Preserve the library on request/parser failures. |
| Custom likes/unlikes can be lost | Remote writes were fire-and-forget; their failure results were ignored. Concurrent writes could arrive out of order. | Journal changes before upload, serialize mutations, retain failed writes for retry, and match acknowledgement revisions. Keep acknowledged intent until a remote snapshot confirms it, preventing stale snapshots from resurrecting unliked tracks. |
| Sign-in and sync feedback | Sign-in captured cookies but did not immediately request a full library sync. Settings could announce success regardless of the result. | Persist the session before completing sign-in, trigger sync immediately, resume sync on startup, and show actual pending/error state. Authenticated requests use the current Music client context. |
| Low-quality artwork | `hqdefault` is 480×360; removing letterboxing and cropping a square leaves about 270×270 usable pixels. Local prepared covers then took precedence in the full player. High-resolution Saavn URLs were also downgraded. | Request HD video artwork with fallback for missing assets, request larger album-CDN covers, preserve larger Saavn sources, and invalidate the old square-art cache. Bound decoding and native artwork size. |
| Lock-screen timeline can disappear | A transient AVPlayer duration of zero could replace known duration metadata. | Ignore nonpositive native duration events, preserving the catalog timeline. Regression test emits the real duration stream event. |
| Failed source switch interrupts working playback | At 02:05:38 JioSaavn has no matching remix; the app then reloads the already-working YouTube source, taking about two more seconds. | If resolution failed before replacement and the original native item is still usable, retain it and its advancing position. Restore by reloading only after the native item actually changed or became unusable. |
| Splash changes shape during launch | Native and Flutter launch views had different credit spacing, and the Flutter view inserted spinner/status content into the centered logo column. The log has roughly 19 seconds between client bootstrap and app start, without stage timings to identify the slow phase. | Match native/Flutter logo, title and credit placement. Keep the requested 1.8-second minimum, show progress separately only after four seconds, and log startup stage timings. No claim that native initialization latency was eliminated. |
| Settings readability | Values shared flexible row space with titles, leaving inconsistent alignment and severe wrapping with large text. A long single screen mixed playback, account, downloads and diagnostics. | Native grouped destination pages, right-aligned values at regular text size, values below labels at large sizes, actual sync controls/status, consistent brand-colored navigation. |

## Other log observations

- A missing JioSaavn match for a remix or music video is normal catalogue behavior. The resolver correctly falls back to YouTube. A forced unavailable source should show failure while preserving current playback.
- Warm JioSaavn replacements in this trace install in roughly 0.6–0.8 seconds. YouTube replacements can take about two seconds to install even with a resolved URL; URL prewarming does not eliminate native network buffering.
- Rapid skips sometimes duplicate an in-flight prewarm resolution. This is a remaining optimization opportunity; this release does not claim to eliminate all duplicate provider requests.
- Native YouTube duration is sometimes approximately double the catalog value: one example reports 574 seconds for a cached 287-second track. Canonical-duration guards remain in place. This audit does not prove or repair an underlying decoder/sample-rate issue; physical-device playback and seek measurements are needed.

## Animated lock-screen artwork

Apple supports `MPMediaItemAnimatedArtwork` from iOS 26. The app provides matching square and portrait previews with on-demand, silent eight-second local video loops. The portrait variant retains the complete square cover over a dimmed artwork background. A documented, one-hook audio_service fork notifies the native bridge after authoritative Now Playing updates. The bridge attaches artwork only when queue entry IDs match, preserving elapsed time, duration and transport metadata.

The movie is generated on a utility queue only when iOS requests it, uses a bounded cache, and falls back to still artwork on unsupported systems or encoding failure. Apple controls animation display and may use the still image for Low Power Mode, Reduce Motion, thermal state or user preferences. CI selects Xcode 26.0.1 so the API is compiled. [Apple documentation](https://developer.apple.com/documentation/mediaplayer/providing-animated-artwork-for-media-items).

## Spotify feasibility

A separate consent-based Spotify OAuth connection could read recently played tracks, saved tracks and top items; it does not require using Spotify for audio playback. Recent history is not a complete lifetime-history export, and the read endpoint does not record Musyn plays in Spotify history. We would need a registered Spotify client and PKCE redirect configuration. No unconfigured sign-in button is added here.

Spotify's recommendations endpoint is deprecated. New development apps currently require an owner with Premium and allow five users; public distribution needs suitable approved access. Any Musyn suggestions based on imported preferences would be a separate recommendation feature, not a promised copy of Spotify's Home feed. Sources: [recently played](https://developer.spotify.com/documentation/web-api/reference/get-recently-played), [saved tracks](https://developer.spotify.com/documentation/web-api/reference/get-users-saved-tracks), [recommendations](https://developer.spotify.com/documentation/web-api/reference/get-recommendations), [current development limits](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide).

## Validation limits

The full Flutter regression suite passes 201 tests. Static analysis and branding/plist checks passed. Automated tests exercise authenticated collection routing, local/remote reconciliation, persisted edits, stale acknowledgements, failure preservation, native-duration events, failed source replacement, settings navigation/back paths, large text, and splash positioning. UI images use fictional fixture content. Native compilation and artifact verification are recorded after the build. This host has no full Xcode or iOS simulator; real-account sync and iPhone lock-screen animation/presentation require device acceptance. No credentials or account cookies are included in fixtures or logs.

## Verified release

### Favorite-heart coherence in 0.1.9

The favorites list and the heart lookup used separate state: the lookup refreshed only when it was empty or a local tap explicitly refreshed it. Once populated, it could miss newly synchronized likes and retain remotely removed likes. Lookup validity now follows the published list snapshot. Regression tests populate the lookup before a sync, then verify both imported favorites and remotely removed favorites. The full local suite passes 201 tests. Version 0.1.9 (10) includes this correction and all changes described above.

### 0.1.8 artifact verification

- [Native build 39380029287](https://github.com/Voryn-Labs/Musyn/actions/runs/39380029287) succeeded from `9819ee616c7370bce526ad8b0daff7c4738d3fe7`, using Xcode 26.0.1 (17A400). Xcode compilation took 161.9 seconds. The complete local Flutter suite passed 200 tests; CI analysis, tests and branding checks also passed.
- [Regular release v0.1.8](https://github.com/Voryn-Labs/Musyn/releases/tag/v0.1.8) was published as a regular release. Downloaded IPA: 12,003,076 bytes, bundle `com.vorynlabs.musyn`, display name Musyn, version 0.1.8 (9), minimum iOS 15.0. ZIP validation, release-feed size and downloaded checksum match. SHA-256: `b5b2638034bc72d83e8f1c9e98c4ff53865169c8e46b58029bc0031904d0e11b`.
- The packaged native executable contains `MPMediaItemAnimatedArtwork`, both square/portrait artwork keys and the metadata-update hook, confirming the iOS 26 implementation was compiled rather than excluded by its SDK guard.
- A portable macOS smoke test of the encoder, adapting only the image loader from UIKit to ImageIO and using a temporary cache, produced playable 640×640 and 600×800 MP4 clips of exactly 8.0 seconds. Extracted frames were visually reviewed. This is asset validation, not a test of lock-screen presentation or a physical iPhone.
- [Shared-source refresh 39384212367](https://github.com/Voryn-Labs/Voryn-Labs.github.io/actions/runs/39384212367) was manually dispatched and succeeded. GitHub Pages completed deployment. The canonical public `https://voryn-labs.github.io/source.json` returned Musyn 0.1.8 (9), 12,003,076 bytes, alongside Cloudified 0.3 (29). No recurring refresh schedule was introduced.

### 0.1.9 artifact verification

- [Native build 39385546753](https://github.com/Voryn-Labs/Musyn/actions/runs/39385546753) succeeded from `17c63b29e73024e6e29e569b495b112e1f337082`, using Xcode 26.0.1 (17A400). Native compilation took 119.3 seconds. Local regression coverage passes 201 tests; CI analysis, tests and branding checks passed.
- [Regular release v0.1.9](https://github.com/Voryn-Labs/Musyn/releases/tag/v0.1.9) is latest, not prerelease. Independently downloaded IPA: 12,002,714 bytes, Musyn, bundle `com.vorynlabs.musyn`, version 0.1.9 (10), minimum iOS 15.0. Archive validation and checksum match; both native animated-artwork keys, the API class and metadata-update hook are present. SHA-256: `6849bc1f2c96468e2afef477062842fda6b8a9f5a71f0c7aa3fc1bd450b62a81`.
- [Manual shared-source refresh 39386238255](https://github.com/Voryn-Labs/Voryn-Labs.github.io/actions/runs/39386238255) succeeded, followed by a successful Pages build of `ed42d714c31a5ad889f9d979bc34a71027698278`. The canonical public source returned Musyn 0.1.9 with the verified 12,002,714-byte IPA and Cloudified 0.3 unchanged. Refresh remains manual only.
