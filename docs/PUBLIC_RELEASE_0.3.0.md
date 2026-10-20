# Musyn 0.3.0 public-release work

## Implemented

- Remove bundled media URL material from JioSaavn decoding and five legacy audit/readme files. User input lives in Keychain with format validation and removal/disable controls. YouTube remains keyless; JioSaavn requests and cached/prepared playback are gated by configuration.
- Add a fourth walkthrough step and a real source-setup page. Settings gains consistent canvas, coral iconography, Privacy, Terms and Support destinations. Source changes refresh discovery.
- Unify player-sheet and queue accent treatment. Simplify the download sheet and avoid a large disabled JioSaavn setup card. Keep the mini player in the shared dock and filter position-only rebuilds. Remove an ineffective opaque blur layer.
- Fix a real navigation transition bug: custom navigation-title styles now match the native back-action `inherit` convention, avoiding TextStyle interpolation assertions between Settings and legal pages.
- Delete the old developer-only automatic GitHub log uploader. Add local redaction, a visible preview, explicit dpaste confirmation with a seven-day expiry request, copy/retry, and a GitHub issue draft. No real user logs were uploaded during development.
- Independently implement opt-in iOS 26 glass and genuine local video artwork using public Apple APIs. Video import validates format, shape, duration, size, playability and silence. Standard UI/still covers remain the fallback. No Spotify tweak hooks or Apple web-token extraction are copied. [Scope and setup](SOURCES_AND_ARTWORK.md).
- Refresh the Musyn product page, brand hub copy, privacy and terms pages, repository presentation and support information. Shared installer updates remain manual.

## Validation and limits

Regression tests exercise configured/unconfigured provider operation, fictional-key decryption, removal, storage failure, prepared-stream gating, diagnostic redaction/upload response validation, user cancellation, legal navigation/back paths and accessible layouts. Headless renders use fictional fixture content. Native crop fixtures exercise production ImageIO code. Release artifact and cleanup verification are recorded below when complete.

This host has no full Xcode or iOS Simulator. Native compilation is performed in CI; physical iPhone glass, lock-screen animation, account sync and frame pacing still require device acceptance. There is no claim of automatic video-artwork discovery, App Store approval or legal certification. Old downloads and third-party copies cannot be recalled.

## 0.3.1 final review

A same-track metadata refresh must redraw the mini player even when the media ID is unchanged. The stream filter now compares object identity because audio_service's MediaItem equality compares only IDs. A widget regression publishes position updates followed by a new artwork URI for the same ID.

Local final checks: 214 deterministic tests passed, Flutter analysis reported no issues, source credential/automatic-upload guard passed, branding checks passed, and production native cover fixtures passed. CI compiles and packages the final iOS artifact separately.

## Published artifact and withdrawal verification — 20 October 2026

- Regular latest release: [0.3.1](https://github.com/Voryn-Labs/Musyn/releases/tag/v0.3.1), build 13. Native build [39420229677](https://github.com/Voryn-Labs/Musyn/actions/runs/39420229677) completed successfully with Xcode 26.0.1.
- Downloaded the public IPA and independently checked `com.vorynlabs.musyn`, display name Musyn, iOS 15 minimum, version/build, matching installer size (12,249,906 bytes), and SHA-256 `42f29e2f6d6c45b12bb0fe99150850a5c79aa639495ac8f9049bb4be41f4b05b`. The packaged credential scan passed.
- The manually triggered shared-source refresh [39425199894](https://github.com/Voryn-Labs/Voryn-Labs.github.io/actions/runs/39425199894) succeeded. The live Pages source advertises Musyn 0.3.1 (13); Cloudified's full catalog entry is unchanged. No recurring source-refresh schedule was added.
- Removed 47 earlier GitHub releases and their tags, plus 22 older Actions artifacts. The release API lists only v0.3.1; the artifact API lists only the verified current build. Published download counters exclude removed releases.
- Prepared an offline Git backup, replaced the removed material in historical blobs/messages, and scanned the sanitized reachable history: 4,124 objects, zero matches. Main and the release tag have identical source trees before/after rewriting. Published both with explicit force-with-lease protection. Native build automation was restored immediately afterward.
- Historical commit IDs changed. Existing clones, private development branches, backups, downloaded copies, forks and GitHub's cached/unreachable objects are outside this public-reference cleanup. Reclone before contributing; do not republish old branches. GitHub support may be required to purge cached historical objects.
- No device, account, signing or user diagnostic data was uploaded for validation. Physical-device acceptance for iOS 26 glass and lock-screen video remains outstanding.
