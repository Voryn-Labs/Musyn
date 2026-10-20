# Musyn audio_service patch

Upstream audio_service 0.18.19 (MIT). LICENSE and upstream sources are preserved. The sole source change emits a notification after authoritative iOS Now Playing metadata updates, with the exact media entry ID. Musyn uses this to attach a user-provided video through the public iOS 26 animated-artwork API without owning the timeline. No Spotify hooks, web tokens or Taurus code are included. Recheck this one hook when updating upstream.
