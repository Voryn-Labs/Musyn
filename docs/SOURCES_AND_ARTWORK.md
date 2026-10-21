# Sources and artwork

YouTube Music is available without an API key. Connecting an account is optional for personal liked music, playlists and sync. Provider availability and service terms still apply.

## Optional JioSaavn

Open Settings → JioSaavn, enter your own **media URL key**, and save. This is the existing DES media-URL format, not an account API token. The field requires eight UTF-8 bytes; Musyn checks format, not authorization or future service compatibility. There is no bundled value, retrieval link or automatic key discovery. Only use material you are authorized to use. Removing the key disables JioSaavn, resets preferred sources, clears prepared selections and retains keyless YouTube operation. A stored key can also be disabled without removing it.

The key is stored in iOS Keychain with `AfterFirstUnlockThisDeviceOnly`, not Hive, source, logs or an environment define. Keychain data can survive uninstall; use Remove key to delete it. No key means JioSaavn network entry points, URL decryption and prepared/cached stream consumption are gated. Existing downloaded files remain the user's local library.

Moving a value into a field is not a legal workaround. JioSaavn's [terms](https://corporate.saavn.com/terms/) restrict unofficial access unless separately authorized. Musyn is not endorsed by the music services and does not grant content rights.

## Automatic artwork on iOS 26

Appearance offers **Glass navigation** and **Automatic artwork**. Automatic artwork is enabled on supported systems unless you explicitly switch it off; existing explicit opt-outs are preserved. You do not import a file or configure another key/account. Earlier iOS versions keep still artwork.

When a track is selected, Musyn matches title, artist and duration against Apple’s public iTunes catalog, then reads animated-cover metadata from that album’s public Apple Music page. It selects a clear HLS rendition backed by a single local MP4. It never extracts the Apple web player’s token, asks for Apple/Spotify login, or forwards YouTube cookies or your JioSaavn key. The album-header parser ignores recommended albums. Version/artist/duration checks reject uncertain matches. Provider markup can change; a failed or unavailable lookup keeps the still cover. This implements Apple animated album covers, not Spotify Canvas.

Lookup and download happen after audio selection and do not block playback. Rapid skips cancel previous work; stale results cannot attach to the newly selected song. Cached clips appear on later visits without another download. The public requests send track metadata and an IP address to Apple; see Privacy.

Clips are limited to 20 MB, 0.5–30 seconds and silent square or 3:4 video. The native validator runs before use. The app’s cache is bounded to 80 MB / 20 clips, outside the backed-up library. Use Settings → Storage & diagnostics → Clear Artwork Cache. Cached matches expire after seven days; confirmed absence expires after one day. Temporary failures use a shorter retry delay; provider refusals/throttling pause lookups. Offline mode, Reduce Motion and Low Power Mode suppress new lookups.

The app loops a matched real asset; iOS 26 Now Playing receives the same local video and matching first-frame preview. iOS controls its lock-screen presentation and can suppress it. No generated cover wiggle or fake artwork movie is used. Legacy manually imported overrides remain readable, but no import action is presented.

[Taurus](https://github.com/samj-exe/taurus), whose source moved to GitLab, was studied as a behavior reference. Its Spotify Canvas flow runs inside the signed-in Spotify client; its Apple catalog flow extracts a web-player token. Neither mechanism or tweak code is included. Musyn independently uses public page metadata and Apple’s native artwork API. The documented audio_service fork only signals exact-entry metadata publication so optional artwork cannot replace the playback timeline. See [the patch](../packages/audio_service/MUSYN_PATCH.md).


## Lock-screen lyrics and sing-along

In the player’s More menu, enable **Lock-screen lyrics**, or use **Settings → Appearance → Lock screen → Current lyric line**. This optional mode replaces the artist row with the current timed lyric and restores the artist when disabled or when no timed lines are available. It is not a separate full-screen lock-screen lyrics panel.

The microphone button on the lyrics screen opens a centered, line-synced sing-along view. Sources without timed lyrics stay readable with an explanation. It does not remove vocals, record the microphone or claim word-level timing from line-level LRC.

Native artwork is adapted to the aspect ratios that iOS advertises. Unavailable clips still retain the static cover. Low Power, Reduce Motion, Auto-Play Animated Images and system presentation settings can prevent animation.
