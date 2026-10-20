# Musyn audio_service patch

Upstream: audio_service 0.18.19, https://github.com/ryanheise/audio_service (MIT; LICENSE preserved).

The only upstream code change posts `MusynNowPlayingInfoUpdated` after the iOS plugin publishes Now Playing metadata, including the current media entry ID. Musyn’s native bridge appends optional iOS 26 animated artwork to that exact entry while preserving the audio plugin’s duration, elapsed time and transport state. It cannot attach a previous track’s animation. macOS and Android behavior is unchanged.

Upstream Dart/plugin sources are included locally so this hook is reproducible in every build; no generated pub-cache mutation is required. Recheck the hook when upgrading audio_service.
