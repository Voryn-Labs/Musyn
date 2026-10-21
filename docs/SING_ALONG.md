# Sing along and lock-screen lyrics

Musyn 0.3.5 (17) replaces the previous visual-only Sing along toggle with real, optional local vocal reduction.

## Use

Open Lyrics or the player More menu → Sing along. iOS 18+ downloads a pinned, checksum-verified 31 MB Mini-BS-RoFormer light model on first use, downloads the selected audio locally if needed, and prepares backing/vocal tracks while the original song continues. Keep Musyn open for preparation. Cancel or skip safely. Once ready, the Vocals slider changes only the separated voice track. The original mix remains available at the right end of the slider or by switching Sing along off. This is model-estimated separation, not access to studio stems or Apple Music Sing. It can leave residual vocals or affect instruments. Tracks must have finite duration up to 15 minutes; preparation speed depends on device, temperature and track length.

No audio uploads. Temporary input and PCM files are removed when work ends. Prepared audio is cached locally (up to five tracks / 200 MB, with the current/recent file retained during replacement); the model remains in Application Support. A song/source change resets the feature. Track IDs, queue order, playback intent and current position survive a successful prepared-source installation; this does not add another history play. Both stems use shared 15% headroom and AAC encoding.

## Lock screen

Settings → Appearance offers independent **Lyrics in artist line** and **Lyrics in artwork** options. The More menu offers Off / Artist line / Artwork / Both. Artwork requires iOS 26. Timed lines are rendered locally as centered pink text, with the next line beneath, into a still preview and tiny silent native artwork clip. Tap the system lock-screen artwork to expand it. Musyn does not replace the iPhone clock, system controls or wallpaper. iOS owns layout, expansion, refresh and power/accessibility limits. Plain untimed lyrics keep the normal cover and metadata. Lyrics can be visible to others who see the lock screen. Turn both options off to restore normal metadata.

The native timeline continues from the canonical audio snapshot; lyric changes never reset elapsed time. Old lookups and old frame renders cannot replace a newly selected track. Currently published artwork files are excluded from cache deletion. Real album animation remains automatic where a confidently matched asset exists.

## Validation

- 266 Flutter tests: quick-skip/stale preparation, cancellation during install/mix, vocal level, metadata/source identity and independent lyric destinations.
- Production STFT round trip mean error 1.36e-8. Real public model inference and full ~9-second generated voice/music separation passed locally on macOS. Recombining two AAC stems produced 0.79% relative reconstruction error. This fixture does not establish subjective quality on all music.
- Production AVAudioMix rendered at vocal gain 0 / 0.4 / 1: backing unchanged, voice gain applied correctly.
- English/Hindi 720×960 posters visually inspected; silent two-second H.264 assets validated.
- iPhone acceptance remains required: native lock-screen expansion/background updates, thermal/battery behavior, real recordings and processing speed. Local host has no iOS simulator.

Model provenance/license: docs/CREDITS.md and assets/licenses/vocal-separator-NOTICE.txt. CI runs the deterministic native DSP/lyric fixtures; the optional real-model fixture is `python3 scripts/test_native_sing.py --model /path/Separator.mlmodelc`. No model, generated voice or real music is committed.
