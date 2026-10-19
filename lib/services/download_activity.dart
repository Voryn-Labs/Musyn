import 'package:flutter/foundation.dart';
import 'package:musyn/services/download_transfer.dart';

enum DownloadStage { queued, downloading, cancelling, saved, failed, cancelled }

class DownloadJob {
  const DownloadJob({
    required this.id,
    required this.song,
    required this.cancellation,
    required this.canCancel,
    this.source,
    this.quality,
    this.resolvedSource,
    this.bitrate,
    this.stage = DownloadStage.queued,
    this.received = 0,
    this.total,
  });
  final int id;
  final Map song;
  final DownloadCancellation cancellation;
  final bool canCancel;
  final String? source;
  final String? quality;
  final String? resolvedSource;
  final int? bitrate;
  final DownloadStage stage;
  final int received;
  final int? total;
  bool get active =>
      stage == DownloadStage.queued ||
      stage == DownloadStage.downloading ||
      stage == DownloadStage.cancelling;
  double? get progress =>
      total != null && total! > 0 ? (received / total!).clamp(0.0, 1.0) : null;
  DownloadJob update({
    DownloadStage? stage,
    int? received,
    int? total,
    String? resolvedSource,
    int? bitrate,
    bool resetTransfer = false,
  }) => DownloadJob(
    id: id,
    song: song,
    cancellation: cancellation,
    canCancel: canCancel,
    source: source,
    quality: quality,
    resolvedSource: resetTransfer
        ? resolvedSource
        : resolvedSource ?? this.resolvedSource,
    bitrate: resetTransfer ? null : bitrate ?? this.bitrate,
    stage: stage ?? this.stage,
    received: resetTransfer ? 0 : received ?? this.received,
    total: resetTransfer ? null : total ?? this.total,
  );
}

/// Session-only transfer visibility. Finished history is bounded; files and
/// offline membership remain owned by the existing atomic download services.
class DownloadActivity {
  final jobs = ValueNotifier<List<DownloadJob>>([]);
  final _entries = <int, DownloadJob>{};
  final _percent = <int, int>{};
  int _nextId = 0;
  int begin(
    Map song,
    DownloadCancellation token, {
    String? source,
    String? quality,
    bool canCancel = true,
  }) {
    final id = ++_nextId;
    _entries[id] = DownloadJob(
      id: id,
      song: Map.from(song),
      cancellation: token,
      canCancel: canCancel,
      source: source,
      quality: quality,
    );
    _publish();
    return id;
  }

  void start(int id) {
    final job = _entries[id];
    if (job != null &&
        job.stage == DownloadStage.queued &&
        !job.cancellation.isCancelled) {
      _entries[id] = job.update(stage: DownloadStage.downloading);
      _publish();
    }
  }

  void resolved(int id, String source, int? bitrate) {
    final job = _entries[id];
    if (job == null || !job.active) return;
    _entries[id] = job.update(resolvedSource: source, bitrate: bitrate);
    _publish();
  }

  void retrying(int id, String source) {
    final job = _entries[id];
    if (job == null || !job.active || job.cancellation.isCancelled) return;
    _percent.remove(id);
    _entries[id] = job.update(resetTransfer: true, resolvedSource: source);
    _publish();
  }

  void progress(int id, int received, int? total) {
    final job = _entries[id];
    if (job == null || !job.active || job.stage == DownloadStage.cancelling)
      return;
    final step = total != null && total > 0
        ? (100 * received / total).floor()
        : received ~/ 262144;
    if (_percent[id] == step) return;
    _percent[id] = step;
    _entries[id] = job.update(received: received, total: total);
    _publish();
  }

  void finish(int id, bool success) {
    final job = _entries[id];
    if (job == null) return;
    _entries[id] = job.update(
      stage: success
          ? DownloadStage.saved
          : job.cancellation.isCancelled
          ? DownloadStage.cancelled
          : DownloadStage.failed,
    );
    _percent.remove(id);
    final finished = _entries.values.where((entry) => !entry.active).toList();
    for (final entry in finished.take(
      (finished.length - 30).clamp(0, finished.length),
    )) {
      _entries.remove(entry.id);
    }
    _publish();
  }

  bool cancel(int id) {
    final job = _entries[id];
    if (job == null || !job.active || !job.canCancel) return false;
    _entries[id] = job.update(stage: DownloadStage.cancelling);
    job.cancellation.cancel();
    _publish();
    return true;
  }

  void dismiss(int id) {
    if (_entries[id]?.active == false) {
      _entries.remove(id);
      _publish();
    }
  }

  void clearFinished() {
    _entries.removeWhere((_, job) => !job.active);
    _publish();
  }

  void _publish() {
    jobs.value = List.unmodifiable(_entries.values.toList().reversed);
  }
}

final downloadActivity = DownloadActivity();
