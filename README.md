<p align="center"><img src="assets/branding/musyn-icon.png" width="128" height="128" alt="Musyn folded music mark"></p>
<h1 align="center">Musyn</h1>
<p align="center"><strong>Music, in your rhythm.</strong><br>An iPhone music player by <a href="https://voryn-labs.github.io/">Voryn Labs</a>.</p>
<p align="center">
<a href="https://github.com/Voryn-Labs/Musyn/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/Voryn-Labs/Musyn?color=FFC5A7&amp;style=flat-square"></a>
<a href="https://github.com/Voryn-Labs/Musyn/actions/workflows/build-ios.yml"><img alt="iOS build" src="https://github.com/Voryn-Labs/Musyn/actions/workflows/build-ios.yml/badge.svg"></a>
<a href="https://github.com/Voryn-Labs/Musyn/releases"><img alt="Release asset downloads" src="https://img.shields.io/github/downloads/Voryn-Labs/Musyn/total?label=release%20asset%20downloads&style=flat-square"></a>
<img alt="GPL 3.0" src="https://img.shields.io/badge/license-GPL--3.0-222222?style=flat-square">
</p>
<p align="center"><a href="https://voryn-labs.github.io/musyn.html">Meet Musyn</a> · <a href="https://github.com/Voryn-Labs/Musyn/releases/latest/download/Musyn.ipa">Download unsigned IPA</a> · <a href="https://voryn-labs.github.io/source.json">Installer source</a> · <a href="https://voryn-labs.github.io/musyn-privacy.html">Privacy</a></p>

## A player that keeps the music in view

| Listen | Organize | Take it with you |
| --- | --- | --- |
| Keyless YouTube Music and optional user-configured JioSaavn AAC | Queue, favorites, folders and your own playlists | Offline tracks and playlist downloads |
| Synced lyrics and a focused full player | Home, moods/genres, search and actual chart playlists | Progress, cancellation, retry and saved-track search |
| Highest/balanced/data-saver YouTube options and JioSaavn 160/320 kbps | Optional YouTube Music account sync | Dark/light appearance, branded walkthrough and opt-in iOS 26 native glass |

See [public-release validation](docs/PUBLIC_RELEASE_0.3.0.md), [privacy](https://voryn-labs.github.io/musyn-privacy.html) and [terms](https://voryn-labs.github.io/musyn-terms.html).

AAC is compressed audio; 320 kbps is **not lossless**. Provider availability and catalogue results can vary. No addon integration is included.

## A look inside

<p><img src="docs/ui-review/home-dark.png" width="210" alt="Musyn Home"><img src="docs/ui-review/player-dark.png" width="210" alt="Musyn player"><img src="docs/ui-review/downloads-dark.png" width="210" alt="Musyn download manager"></p>

These are automated Flutter renders with fictional sample tracks and placeholder artwork. They show layout, not a device playback test. [More previews](docs/ui-review/README.md).

## Install Musyn

Musyn combines YouTube Music integration, offline downloads, synced lyrics and a queue you control. More providers can be introduced as the project grows. Real video artwork and native glass are opt-in on iOS 26; tracks without a clip keep still covers.

**JioSaavn is optional.** Musyn supplies no media URL key. Add your own in Settings → JioSaavn; it stays in iOS Keychain. YouTube works without it. [Source and artwork setup](docs/SOURCES_AND_ARTWORK.md).

Requires **iOS 15+**. Download `Musyn.ipa` and its SHA-256 checksum from the [latest release](https://github.com/Voryn-Labs/Musyn/releases/latest). The IPA is **unsigned**. Use your own signing identity with a compatible installer, or import it into a compatible LiveContainer version. AltStore PAL cannot install this unsigned build. Installer and host restrictions still apply.

One Voryn Labs source for **Musyn and Cloudified**: `https://voryn-labs.github.io/source.json`. The maintainer refreshes the shared catalog manually after publishing new app releases.

Identity: `com.vorynlabs.musyn` · publisher **Voryn Labs**. This is a fresh identity with no legacy migration. The download badge measures release asset requests, not unique users or installations.

## Build and contribute

```sh
flutter pub get
flutter analyze
flutter test
python3 scripts/verify_branding.py
flutter build ios --release --no-codesign
```

Pinned CI toolchain: Flutter 3.47.7 / Dart 3.13.5. iOS builds require full Xcode. CI selects Xcode 26.0.1. Optional iOS 26 native glass and local video artwork use public Apple APIs; earlier versions keep the standard UI. Native dependencies use Swift Package Manager. GitHub Actions builds and verifies the IPA, generates its source feed from the actual binary, and publishes a regular release only when requested. Existing releases are never silently replaced. See [build/release notes](docs/BUILD.md), [flow map](UI-FLOW-MAP.md) and [verification](VERIFICATION.md).

Automated tests cover playback coordination and UI flows. Physical iPhone lock-screen playback, interruptions, real provider availability and installer behavior still require acceptance; no universal reliability claim is made.

## Credits and license

Maintained by **Voryn Labs** under [GPL-3.0](LICENSE). Developed from the Musified/Musify lineage; the interface work references BitChord. Upstream authors, vendored libraries and providers retain their credits and rights. [Full credits](docs/CREDITS.md). Music and artwork remain the property of their respective owners.

## Support and contributing

Use **Settings → Storage & diagnostics → Diagnostic Logs** to review a redacted preview, choose a public dpaste upload, or open a GitHub issue draft. Nothing uploads automatically. [Report a bug](https://github.com/Voryn-Labs/Musyn/issues/new/choose), [request a feature](https://github.com/Voryn-Labs/Musyn/issues/new/choose), or read [SECURITY.md](SECURITY.md) for private disclosures.

Please include the app/build and iOS version, installer, reproduction steps and expected behavior. Never share provider keys, account cookies or signing credentials. The download counter measures release asset requests from currently published releases, not unique installations.
