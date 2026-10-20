# Automatic artwork — 0.3.3

Manual video import did not meet the requested Taurus-like experience. This release replaces that flow with independent automatic Apple album-cover discovery. It uses neither Taurus’s Spotify session hooks nor its Apple web-player token extraction.

## Pipeline

Selection → debounce/cancel previous work → public iTunes track match → exact album header on the public Apple Music page → suitable unencrypted HLS rendition → bounded local MP4 download → native validation → player and exact-entry Now Playing enrichment. HTTP, parsing and download are separate from audio source installation; HTML parsing runs off the UI isolate.

Artist, title/version and available duration checks reject uncertain recordings. Album metadata ranks candidates. Only the matched album header supplies video; related/recommended albums are ignored. Redirects and media hosts are restricted. Encrypted/split-segment/unsupported or oversized clips fall back to still artwork. No actual media asset or token is bundled.

## Availability and storage

Automatic artwork is on for supported systems without a saved preference; explicit opt-outs are retained. Settings includes the switch and a cache-clear action. Privacy and onboarding disclose Apple metadata requests. Cached files live in the OS cache directory with an 80 MB / 20-clip limit, each at most 20 MB. New lookups are debounced, spaced, cancelled on selection changes and suppressed offline or under accessibility/power constraints. Successful matches are cached for seven days, confirmed absences for a day, and temporary errors do not become permanent misses.

This finds Apple animated album covers, not Spotify Canvas. Albums with no suitable clip or no confident match retain still artwork. iOS controls lock-screen availability.

## Verification

Deterministic tests cover matching and Unicode names, album identity, safe HLS parsing, redirects, byte limits, cancellation, opt-out, caching, cache bounds and stale same-ID metadata. A separately enabled real-network test resolved Taylor Swift’s Anti-Hero to a public album cover and downloaded its actual video with no account/token. Production AVFoundation validation is exercised separately against that file. No media was added to the repository. Local validation: 241 deterministic tests passed; Flutter analysis, branding checks, the public-source credential guard and Swift syntax parsing passed. The real public lookup downloaded a roughly 4.5 MB clip; the production AVFoundation validator accepted it as a silent 22.67-second video. The UI render suite passed 80 tests. Cache tests also verify that native Now Playing references are released before deletion and that pruning retains any older clip still published by iOS.

Native iOS compilation is performed in CI; lock-screen presentation/frame pacing still require a physical device.
