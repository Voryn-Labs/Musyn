# Sing Along — upcoming

The slow experimental vocal-reduction flow is disabled in this build. The
Lyrics microphone and player menu clearly label Sing Along as coming soon and
open an informational preview. That preview cannot start downloads, model
loading, preparation or an audio-source switch. Normal synced lyrics, line
seeking and lock-screen lyrics remain available.

The intended feature reduces the singer's vocals while backing instruments keep
playing, with timed lyrics and an adjustable vocal level. It must start quickly
when explicitly requested. Stereo center cancellation is not an equivalent:
it can suppress centered instruments too. No Sing work should run on ordinary
Play, startup, track changes, or connecting CarPlay.

## Work retained for development

The batch separator from 0.3.5/0.3.6 is retained behind a disabled availability
gate, including cache lookup before re-download, overlapping on-demand model and
source setup, content checks, cancellation and separate backing/vocal gain.
A rolling two-second PCM reader removes the full-track scratch-file decode and
is covered by native ordering/tail/cancellation fixtures. This is groundwork;
the exported-track player still waits for completion. It is **not** a finished
near-instant streaming player.

See `SING_ALONG_ENGINE_RESEARCH.md` for the GPL-3.0 Vitrine streaming reference,
benchmarks and remaining timeline/read-ahead work. Re-enable only after a real
streaming consumer is integrated and startup, seek, skip, pause, background,
voice/backing balance, memory and thermal behavior are verified on iPhone.

## Lock screen

Settings → Appearance offers independent **Lyrics in artist line** and **Lyrics in artwork** options. The More menu offers Off / Artist line / Artwork / Both. Artwork requires iOS 26. Timed lines are rendered locally as centered pink text, with the next line beneath, into a still preview and tiny silent native artwork clip. Tap the system lock-screen artwork to expand it. Musyn does not replace the iPhone clock, system controls or wallpaper. iOS owns layout, expansion, refresh and power/accessibility limits. Plain untimed lyrics keep the normal cover and metadata. Lyrics can be visible to others who see the lock screen. Turn both options off to restore normal metadata.

The native timeline continues from the canonical audio snapshot; lyric changes never reset elapsed time. Old lookups and old frame renders cannot replace a newly selected track. Currently published artwork files are excluded from cache deletion. Real album animation remains automatic where a confidently matched asset exists.

## Historical experimental validation

- 266 Flutter tests: quick-skip/stale preparation, cancellation during install/mix, vocal level, metadata/source identity and independent lyric destinations.
- Production STFT round trip mean error 1.36e-8. Real public model inference and full ~9-second generated voice/music separation passed locally on macOS. Recombining two AAC stems produced 0.79% relative reconstruction error. This fixture does not establish subjective quality on all music.
- Production AVAudioMix rendered at vocal gain 0 / 0.4 / 1: backing unchanged, voice gain applied correctly.
- English/Hindi 720×960 posters visually inspected; silent two-second H.264 assets validated.
- iPhone acceptance remains required: native lock-screen expansion/background updates, thermal/battery behavior, real recordings and processing speed. Local host has no iOS simulator.

Model provenance/license: docs/CREDITS.md and assets/licenses/vocal-separator-NOTICE.txt. CI runs the deterministic native DSP/lyric fixtures; the optional real-model fixture is `python3 scripts/test_native_sing.py --model /path/Separator.mlmodelc`. No model, generated voice or real music is committed.
