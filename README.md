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

## Your music. Your way.

- **Stream your favorites** — YouTube Music without API keys, plus optional JioSaavn AAC up to 320 kbps.
- **Take music offline** — song and playlist downloads, source and quality preferences, progress and retry.
- **Follow every line** — synced lyrics, lyric seeking and optional lock-screen lyrics.
- **Make the queue yours** — play next, reorder, shuffle, favorites, playlists and folders.
- **Bring your YouTube library** — connect YouTube Music for liked music and playlist sync.
- **Enjoy the player** — portrait and landscape layouts, light/dark themes, and optional glass and automatic animated artwork on iOS 26. Covers stay still when no matching animation is available.
- **Listen with CarPlay** — browse your queue, downloads, favorites and recent tracks. Requires CarPlay-enabled signing.

**Coming soon: Sing Along.** Turn down the singer’s voice while the backing music and live lyrics continue. We’re improving startup speed; vocal reduction is currently disabled. Synced lyrics work now.

## Get Musyn

**[Download 0.3.7](https://github.com/Voryn-Labs/Musyn/releases/tag/v0.3.7)** · iOS 15+ · Unsigned IPA

Sign the IPA with your preferred compatible installer. Add the shared Voryn Labs source to browse **Musyn and Cloudified**:

```text
https://voryn-labs.github.io/source.json
```

**Optional JioSaavn:** add your own authorized media URL key in Settings → JioSaavn. Setup search phrase: **“JioSaavn media URL key.”** Musyn supplies no key; YouTube works without one.

## Open source, open to ideas

Built by **[Voryn Labs](https://voryn-labs.github.io/)** under [GPL-3.0](LICENSE). Required upstream attribution and dependency notices are kept in [Credits](docs/CREDITS.md). [Privacy](https://voryn-labs.github.io/musyn-privacy.html) · [Terms](https://voryn-labs.github.io/musyn-terms.html).

[Report a bug or suggest a feature](https://github.com/Voryn-Labs/Musyn/issues/new/choose). You can review and share diagnostic logs from Settings; nothing uploads automatically. Keep keys and account credentials out of reports. The download badge counts release asset downloads, not unique users.

<details>
<summary>Build it yourself</summary>

Use Flutter 3.47.7 and full Xcode.

```sh
flutter pub get
flutter analyze
flutter test
flutter build ios --release --no-codesign
```

</details>
