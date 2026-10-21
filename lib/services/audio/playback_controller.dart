import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musyn/models/full_player_state.dart';
import 'package:musyn/models/position_data.dart';

/// UI-facing playback contract, independent of the concrete engine and services.
abstract class PlaybackController extends BaseAudioHandler {
  AudioPlayer get audioPlayer;
  ValueNotifier<String?> get currentPlayingYtid;
  ValueNotifier<int> get queueItemCount;
  Stream<List<Map>> get queueAsMapStream;
  Stream<FullPlayerState> get fullPlayerStateStream;
  Stream<PositionData> get positionDataStream;
  int get currentQueueIndex;
  bool get hasNext;
  bool get hasPrevious;
  Future<void> addToQueue(Map song, {bool playNext = false});
  Future<void> addPlaylistToQueue(
    List<Map> songs, {
    bool replace = false,
    int? startIndex,
    bool resetShuffle = true,
  });
  Future<void> playSingleSong(Map song);

  /// Resolve one likely first selection without selecting or starting playback.
  Future<void> primeSong(Map song) async {}
  Future<void> playPlaylistSong({
    Map<dynamic, dynamic>? playlist,
    required int songIndex,
  });
  Future<void> playNext(Map song);
  Future<void> playAgain();
  Future<void> skipToSong(int index);
  Future<void> removeFromQueue(int index);
  Future<void> reorderQueue(int oldIndex, int newIndex);
  void clearQueue();
  void clearPinnedSources();
  void clearPreparedStreams();
  Future<String?> switchSource(String source);
  void clearPreparedArtwork() {}

  Future<bool> installVocalStems(String entryId, String path) async => false;
  Future<void> setSleepTimer(Duration duration);
  void cancelSleepTimer();
  Future<void> setSleepTimerEndOfSong();
  Future<void> resyncAfterForeground();
}
