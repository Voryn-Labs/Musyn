# Musified reliability implementation

Keep Flutter, the existing library and lyrics. Addon integration and lossless are outside the agreed scope. UI changes follow the functional fixes. Work is on `codex/musified-reliability`; device verification is required before claiming iOS playback reliability.

1. **Playback and queue:** protect pause/stop intent across asynchronous loads; prevent stale skips and failures from changing the latest selection; bound source-install mutations; correct seek completion and interruption recovery. Regression tests cover delayed and superseded work.
2. **Source selection:** preserve paused state and queue occurrence when switching, honor explicit source choices, and keep canonical catalogue identity separate from fallback playback identity. Test source policy independently from network services.
3. **Downloads:** deduplicate in-flight requests, write temporary assets and commit only completed transfers, cancel active playlist transfers, capture per-batch source/quality, and persist only valid completed files. Test cancellation, failures and concurrent requests.
4. **Charts and search:** parse actual chart sections and preserve provenance/order; remove generic Explore fallback from charts; make search categories independent and reject stale replies. Test captured response fixtures without live services.
5. **UI last:** update player/source controls and download progress/actions around the corrected behavior, preserve lyrics and overall identity, and remove inaccurate quality labels. Visual/motion QA remains required on simulator/device.

## Acceptance

- All offline unit/widget tests and analyzer checks pass, or baseline/environment failures are identified explicitly.
- Phone checks: natural next while locked, rapid Next/Previous, pause/stop during loading, paused/playing source switches, Control Center seek and interruption recovery.
- Download checks: network loss, cancellation, repeated taps, playlist completion, relaunch and offline playback.
- Chart checks: selected chart opens the correct ordered playlist; no Explore/video fallback is mislabelled as a song chart.
- Decoder replacement is considered only with evidence from representative AAC/source fixtures and device logs.

## Status

Phases 1–4 are implemented locally, with automated regression coverage for the isolated playback, queue, transfer, registry, artwork and parser behavior. Phase 5 has targeted source and download controls implemented and widget-tested. A broader visual redesign and visual/motion acceptance remain pending simulator/device review.

Validation on 2026-10-18: **58 offline tests passed**. Analysis reports **no errors or warnings**, with 68 informational lint notices remaining (the original checkout reported 70). `git diff --check` passes. Tests used temporary Flutter 3.47.7 / Dart 3.13.5; dependency resolution refreshed five SDK-pinned entries in `pubspec.lock` without adding a package. The existing CI workflow follows Flutter stable.

Full Xcode and a simulator are unavailable on this host, so native iOS compilation, physical lock-screen playback, background transfers and visual/motion QA are not verified. The current implementation uses the existing just_audio engine. See `VERIFICATION.md` for changes, coverage and the remaining acceptance checks.
