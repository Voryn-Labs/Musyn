# Verification of the supplied 0.3.4 source audit

Reviewed against current main while preparing 0.3.5 (17). This is source verification and automated testing, not an Instruments or physical-iPhone run.

| Finding | Verification and change |
| --- | --- |
| Backgrounding can trigger false skip | The watchdog did advance a ready track after quiet position observations. just_audio extrapolates position, so suspension alone is not a reproduced cause. The unsafe policy is removed: callback gaps reset observation, ready tracks can only resume themselves, and queue advancement requires freshly observed ended state with transition/state revalidation after session activation. |
| Automatic artwork forgotten on launch | Confirmed. Cleanup now reads the namespaced inline `at` timestamp and preserves positive entries for seven days / misses for one day, matching the artwork store. Audio-cache clearing also preserves this separate index. |
| Cold-start playlist link dropped | Confirmed. A bounded, deduplicated inbox defers imports until the real app navigator mounts, including after onboarding. Imports are serialized and persisted before completion; a missing toast context never discards library data. |
| Sing along UI stays selected after track change | Confirmed. The player resets its visual mode by queue-entry/source identity, including repeated instances of the same song. |
| Clear Artwork Cache misses square covers | Confirmed. The action now waits for pending square jobs, clears resolved URI lookup, image disk/decoded/provider caches, and invalidates prepared handler covers, in addition to motion clips. The old unused broad `clearCache` was replaced by this targeted action. |
| Pending square work forgotten at 40 | Confirmed. A bounded shared-job pool retains existing joins and rejects additional work at capacity. Running decodes are never evicted from its index. |
| Range fallback can download whole audio | Confirmed. Both HEAD and fallback GET use streamed responses and immediately cancel the body, even when Range is ignored; the owned client closes in `finally`. |
| Memory cache keeps mutable/expired values | Confirmed. Reads/inserts prune expired entries, writes snapshot nested maps/lists/bytes, and cache returns are isolated copies. The existing 200-entry cap remains. |

Removed the identity `_decodePathParameter` wrapper; route parameters use the router's decoded value directly. Tab paths have one source of string constants. The audio handler remains intact rather than being mechanically split. Existing image/clip/log/history limits and proxy-disabled playback are retained.

Validation: clean Flutter analysis; **266 tests passed**. Added regressions cover suspension gaps, ended-state observations, pre-mount playlist import in the actual app, deferred-link deduplication, 40-job coalescing, ignored-Range stream cancellation/client closure, launch cleanup lifetime, nested mutation isolation, and same-song/different-entry Sing along state. Existing native timeline and artwork fixtures passed. Device acceptance is still needed for real iOS suspension, lock-screen updates and processing speed.
