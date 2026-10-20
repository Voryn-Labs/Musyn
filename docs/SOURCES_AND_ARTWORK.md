# Sources and artwork

YouTube Music is available without an API key. Connecting an account is optional for personal liked music, playlists and sync. Provider availability and service terms still apply.

## Optional JioSaavn

Open Settings → JioSaavn, enter your own **media URL key**, and save. This is the existing DES media-URL format, not an account API token. The field requires eight UTF-8 bytes; Musyn checks format, not authorization or future service compatibility. There is no bundled value, retrieval link or automatic key discovery. Only use material you are authorized to use. Removing the key disables JioSaavn, resets preferred sources, clears prepared selections and retains keyless YouTube operation. A stored key can also be disabled without removing it.

The key is stored in iOS Keychain with `AfterFirstUnlockThisDeviceOnly`, not Hive, source, logs or an environment define. Keychain data can survive uninstall; use Remove key to delete it. No key means JioSaavn network entry points, URL decryption and prepared/cached stream consumption are gated. Existing downloaded files remain the user's local library.

Moving a value into a field is not a legal workaround. JioSaavn's [terms](https://corporate.saavn.com/terms/) restrict unofficial access unless separately authorized. Musyn is not endorsed by the music services and does not grant content rights.

## iOS 26 options

Settings → Appearance offers **Native glass** and **Animated artwork**, both opt-in and disabled on unsupported systems. Native glass uses `UIGlassEffect` for the dock, player controls and sheets. Earlier systems retain the standard presentation.

For real motion, open a song's menu → **Add video artwork**. Choose a silent square (1:1) or portrait (3:4) MP4/MOV, 0.5–30 seconds, under 20 MB, that you have permission to use. The app validates playability, duration, shape and absence of an audio track before copying it locally. The player loops the actual clip and iOS 26 Now Playing receives the same local asset and matching first-frame preview. Remove video artwork from that song's menu when no longer wanted.

Tracks without an imported clip keep still artwork. The system can suppress lock-screen animation; Reduce Motion, Low Power Mode and background lifecycle pause in-app video. There is no generated sleeve wiggle or fabricated artwork movie. This release does not discover Apple Music album clips or Spotify Canvas automatically.

[Taurus](https://github.com/samj-exe/taurus), with source relocated to GitLab, was studied as a behavior reference. Its Canvas flow depends on Spotify's authenticated client and its Apple catalogue flow extracts a web token. Those mechanisms and its tweak code are not included. Musyn implements the public Apple APIs independently. The small documented audio_service fork adds only an exact-entry metadata notification so optional artwork cannot replace the playback timeline. See [the patch](../packages/audio_service/MUSYN_PATCH.md).
