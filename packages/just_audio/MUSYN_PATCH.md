# Musyn patch to just_audio 0.10.6

Upstream: https://github.com/ryanheise/just_audio (MIT; LICENSE retained).

- `AudioPlayer.setMusynVocalLevel(0..1)` sends a private native method to its existing player channel.
- Darwin applies AVAudioMix only to local `.musyn-stems.mov` files with exactly two audio tracks ordered by track ID: backing at gain 1, voice at the requested gain.
- Prepared sources start with both tracks audible. This preserves the original mix if preparation is cancelled during installation.
- Repeat items inherit the current vocal balance, including copies created after the slider changes.
- Ordinary sources and global volume are unaffected. Unsupported platforms reject vocal preparation before this method is used.

The production helper is exercised by scripts/test_native_sing.py --model PATH using a locally generated voice/music fixture.
