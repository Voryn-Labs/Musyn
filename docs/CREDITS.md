# Credits

Musyn is maintained by Voryn Labs under GPL-3.0. It develops an iOS music player from the Musified/Musify code lineage. Original Musify project: https://github.com/gokadzev/Musify.

The current navigation/player visual work references BitChord: https://github.com/kushagrasinghx/BitChord (GPL-3.0). No addon modules are included.

Flutter, just_audio, audio_service, Hive and the vendored YouTube libraries retain their own notices and licenses. Lyrics are provided through LRCLIB. Audio providers and artwork owners retain their rights; this project does not distribute a music catalogue.

Taurus was studied as an iOS 26 behavior reference. No Taurus tweak code, Spotify hooks or extracted Apple web token is included. Native materials and video artwork use Apple public APIs. The MIT audio_service fork retains upstream notices and documents its metadata/timeline patches in packages/audio_service/MUSYN_PATCH.md.

Vocal separation uses the MIT Mini-BS-RoFormer light Core ML conversion published at https://huggingface.co/My-Name-Is-Jeff/vitrine-sing, pinned to revision 14326ee9a607d47ebfe962e0ac18ef6c76746929. The complete upstream/conversion MIT notices are shipped in assets/licenses/vocal-separator-NOTICE.txt. Model binaries download on demand and are not bundled. Musyn’s STFT adapter, preparation pipeline, lyric renderer and UI are independent implementations. The MIT just_audio fork documents its small native stem-mix extension in packages/just_audio/MUSYN_PATCH.md.
