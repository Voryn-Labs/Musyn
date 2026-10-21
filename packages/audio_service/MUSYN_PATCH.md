# Musyn audio_service patch

Upstream audio_service 0.18.19 (MIT). LICENSE and upstream sources are preserved.

The iOS fork publishes an exact media-entry-ID notification after authoritative Now Playing updates and when the service stops. Musyn’s native enrichment layer uses a timestamped copy of that canonical snapshot to add real animated artwork and optional current-line lyrics without rewinding the playback clock.

Timeline changes in 0.3.4 preserve a positive same-entry duration through artwork/metadata refreshes, recover missing durations from catalogue seconds, reset the duration across entries, explicitly publish finite-track live state, extrapolate elapsed time to publication, use a nonzero default playback rate and freeze the effective rate during pause/buffering. Stop clears stale metadata and tells enrichment to stop lyric updates.

`python3 scripts/test_native_now_playing.py` exercises the actual production Objective-C arithmetic with Foundation. Recheck these changes when rebasing upstream. No Spotify hooks, web tokens or Taurus code are included.
