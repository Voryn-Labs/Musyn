# Sing Along latency review — 2026-10-22

The production pipeline downloads the full song, installs the model if absent,
decodes the whole file, separates two-second windows and exports a complete AAC
asset before installing it. Windowed inference alone is not streaming playback.

This revision checks a bounded provider/recording/encode alias before downloading
again. Outputs remain keyed by content hash. Unknown identities/local files keep
content validation. The five pinned model files download concurrently as one
operation, overlapping the song download only after the explicit Sing tap.
Selection, ordinary Play, launch and connecting CarPlay do not install/load a
model, download a source for Sing or run separation. Original audio continues.
These fixes improve setup/repeat use, not instant first-time whole-song playback.

## Closest reference: Vitrine

GPL-3.0 source reviewed at `914343731f66ccb2e639b8164a36be849a043276`:
- https://github.com/My-Name-Is-Jeff/vitrine/blob/914343731f66ccb2e639b8164a36be849a043276/tweak/Sources/Shared/Sing/SGSingEngine.m
- https://github.com/My-Name-Is-Jeff/vitrine/blob/914343731f66ccb2e639b8164a36be849a043276/tweak/Sources/Shared/Sing/SGSingLoader.m
- https://github.com/My-Name-Is-Jeff/vitrine/blob/914343731f66ccb2e639b8164a36be849a043276/harness/sing/README.md

Its worker separates overlapping windows into bounded audio/vocal rings, keeps a
short adaptive read-ahead, crossfades reduction, flushes on track/seek changes and
returns the original mix when the worker falls behind. Tests cover audio order,
clock correction, slow decoders, cancellation and no render-thread allocations.
It hooks Spotify's renderer, so it is not a drop-in just_audio/AVPlayer component.
No Vitrine application code is copied into this revision.

The next production engine needs an on-demand native streaming separator/mixer
and explicit playback-delay accounting, retaining ordinary AVPlayer while Sing
is off. It must prove timeline correctness, seek behavior and uninterrupted audio
before replacing the batch path. Stereo center cancellation is not equivalent:
it suppresses centered instruments too and fails on mono recordings.

## Other projects

- https://github.com/kristerssaulitis/stemsplitter — MIT Swift/Core ML offline
  splitter; useful bounded file I/O, not evidence of instant live karaoke.
- https://github.com/demixr/demixr-app — mobile GPU separation reference. README
  mixes current/legacy performance notes; benchmark independently.
- https://github.com/sweetspotsoundsystem/StemgenRT-5.8 — MIT causal streaming
  model/inference; needs an iOS port and device quality/thermal measurements.
  Algorithmic latency is not iPhone startup latency.
- https://github.com/rapidly-labs/rapidly-sdk — proprietary commercial LICENSE;
  unlicensed output is watermarked. Not an open-source dependency for Musyn.

## Local experiment, not an iPhone benchmark

Existing 31 MB light model, three silent windows per configuration, developer Mac:

| Compute | Load | First window | Later windows |
|---|---:|---:|---:|
| all | 24.30 s | 0.264 s | 0.211–0.221 s |
| CPU/GPU | 0.52 s | 1.994 s | 0.185–0.187 s |
| CPU | 0.53 s | 0.380 s | 0.345–0.345 s |

Configurations ran in that order; Core ML may reuse compiled resources. Loads
are not a controlled cold-compile comparison. Silence is not a quality test.
Do not infer phone latency, battery use or a universal compute policy. The
experiment identifies model setup and the whole-file export gate as distinct
startup costs. No compute policy was changed from this experiment alone.
