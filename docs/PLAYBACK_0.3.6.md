# Playback diagnostic follow-up — 0.3.6 (18)

The supplied diagnostic log shows Casa selected at 16:50:51, with `target=youtube saavnSearch=false`. YouTube returned rate-limit errors through several client attempts. The selected song timed out after 36,003 ms; error recovery then advanced to another queued song. No successful Casa source installation appeared in that interval. This establishes a resolver/throttle failure plus misleading selection and recovery behavior, rather than an artwork-download delay. Native installations elsewhere in the log took about 0.8–2.6 seconds even for warmed URLs; stream/CDN startup remains a separate cost.

The no-key JioSaavn concern was partly confirmed: actual JioSaavn search/decryption was already guarded by `jiosaavnAvailable`, but stale preferences and resolved metadata could still reject prepared YouTube URLs and log JioSaavn as the target. Both routing helpers and resolution logging now respect availability first. Nothing about the key itself is logged.

Track changes pause old audio while retaining its native item/session, then publish the selected loading state. Failed requests retain the selected queue entry in error state; Play must establish that entry's source before resuming. A failed user selection no longer schedules background retry/next actions. Native ready/duration/error notifications are guarded against old or pending selections. Rapid selection and failure cleanup recheck ownership after awaits.

YouTube rate limiting now stops SDK retries and cross-client attempts immediately and imposes a 30-second manifest/preload cooldown. Prepared URLs can still play. Each manifest resolution owns and closes its transport, including after timeout, with a 12-second total / six-second per-client budget. No request evasion or extra account is introduced.

The log also contained Flutter `_HeroFlight` null-check exceptions. The custom player sheet now excludes Hero flights, using its existing slide/spring gesture transition instead.

Validation: clean analysis; 274 Flutter tests. Regression tests use the real handler with controlled native-player and resolver seams: old audio is paused before new metadata; Pause/Play cannot revive the old item during lookup; repeated failures stay on the chosen entry; Play retries that entry; late results cannot replace a newer selection. The real YouTube resolver was exercised against a mocked HTTP 429: one request, owned client closed, no further requests during cooldown. Physical-device verification is still needed for background execution, actual network startup and gestures. No user diagnostic log is committed.

## Published artifact

[Musyn 0.3.6 (18)](https://github.com/Voryn-Labs/Musyn/releases/tag/v0.3.6) is a regular release. [Build 39623189082](https://github.com/Voryn-Labs/Musyn/actions/runs/39623189082) passed all checks and packaging. The downloaded IPA passed identity/version checks and the removed-provider-material scan. Size: 12,425,294 bytes. SHA-256: `57f7bef642c567389003adaec281f90d14784517b0218e5643f52aac0d619a28`.

[Manual shared-source refresh 39624172499](https://github.com/Voryn-Labs/Voryn-Labs.github.io/actions/runs/39624172499) succeeded; its catalog records version 0.3.6, build 18 and the verified download size. Cloudified remains 0.3. Updates remain manual-only.
