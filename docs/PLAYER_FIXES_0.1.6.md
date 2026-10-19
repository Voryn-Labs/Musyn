# Musyn 0.1.6 player fixes

The supplied October 19 device logs show two separate transition delays:

1. `getPlaybackUrl` attempts to merge a dynamically typed prepared metadata map into a `Map<String, dynamic>`. Dart rejects that merge, so valid prepared JioSaavn URLs fall through to YouTube. Logged examples spend roughly 7–8 seconds resolving and installing the fallback.
2. A serialized native-install queue waits for the previous load even after the user requests another song. The installed just_audio 0.10.6 API explicitly supports interrupting `setAudioSources` with a newer invocation; the native iOS implementation aborts an existing loading connection. The extra application queue defeated this behavior.

The metadata merge now checks and assigns string keys individually. Native installs can be superseded, and every continuation retains the transition-generation check. Manual replacement no longer adds a pause and session-reactivation round trip. The player uses native HTTP request headers rather than a Dart localhost proxy, and Darwin buffering requests five seconds with automatic startup waiting disabled. This may trade earlier starts for rebuffering on a poor connection; device measurements are needed. It does not promise instant playback from an uncached network source.

Artwork preparation runs separately from playback. It upgrades low-resolution URLs, removes YouTube thumbnail letterboxing, crops a square cover and publishes a local cached URI to the app and Now Playing. Completion checks both the selected media ID and original artwork URI, so an old result cannot replace a new track. Cached covers are reused through duration and provider metadata updates.

Download source and quality are persistent Settings options. One download job owns up to one attempt per enabled provider, atomic writes, cancellation and progress. A brief toast announces fallback; byte totals and bitrate reset between attempts. Ordinary Download starts immediately; Track Options retains an explicit override sheet. Download preference changes do not invalidate streaming caches.

The full player follows Apple Music's portrait arrangement and uses the system route picker on iOS. The supplied clip shows landscape artwork beside lyrics; the landscape layout follows that arrangement. Lyrics are centered, the active line is pink, and stage font size stays constant across activation. Plain lyrics are centered too. The mini-player keeps its compact reserved dock and swipe/pull gestures, with refined spacing and a finer progress indicator.

Local validation: static analysis is clean; branding and plist checks pass; the focused player suite passes 57 widget tests, including 568×320 landscape at 1.8× text size. The full pre-release regression run is recorded below. No iPhone simulator or full Xcode installation is available on this host; native compilation runs on GitHub's macOS runner. Headless Flutter renders are saved under `docs/ui-review/`. The native route picker cannot be evaluated in those renders. Device-only background/audio-output behavior remains an acceptance check, not a claimed verified result.

The logs also show native AAC durations at roughly twice the catalog duration. Existing canonical duration and end-of-track guards are retained. This change does not claim to repair a decoder or sample-rate problem without a device reproduction.

Release validation: 175 Flutter tests passed locally, including the full queue/favorites/download suite. Static analysis, branding verification and both iOS plist checks passed. New downloaded artwork uses the same high-resolution square-cover preparation. The release workflow subsequently completed native compilation, packaging and publication successfully.

Verified release: [iOS build 39312408361](https://github.com/Voryn-Labs/Musyn/actions/runs/39312408361), built from `b43f8050217b74e0c8be3a76576ee65b9dd518d0`. Downloaded `Musyn.ipa` is a valid ZIP, version 0.1.6 (7), bundle `com.vorynlabs.musyn`, 11,947,810 bytes. SHA-256: `ef6eeb5b786c28e9f9c1317af9da6da8781e39fc575b82cd166bf49aa97ec82c`. The downloaded checksum and release feed both match the IPA. The shared website catalog was not refreshed.
