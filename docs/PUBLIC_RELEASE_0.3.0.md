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
