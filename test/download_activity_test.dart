import 'package:musyn/utilities/app_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/download_activity.dart';
import 'package:musyn/services/download_transfer.dart';
import 'package:musyn/utilities/library_ranking.dart';

void main() {
  test('source fallback clears previous provider bitrate and byte total', () {
    final activity = DownloadActivity();
    final id = activity.begin({'ytid': 'fixture'}, DownloadCancellation());
    activity.start(id);
    activity.resolved(id, 'jiosaavn', 320);
    activity.progress(id, 900, 1000);
    activity.retrying(id, 'youtube');
    final job = activity.jobs.value.single;
    expect(job.received, 0);
    expect(job.total, isNull);
    expect(job.bitrate, isNull);
    expect(job.resolvedSource, 'youtube');
    expect(job.stage, DownloadStage.downloading);
  });

  test(
    'actual transfer source and bitrate override catalogue and requested limit',
    () {
      final activity = DownloadActivity();
      final id = activity.begin(
        {'catalogOrigin': 'saavn'},
        DownloadCancellation(),
        source: 'youtube',
        quality: '160',
      );
      expect(activity.jobs.value.single.source, 'youtube');
      expect(activity.jobs.value.single.resolvedSource, isNull);
      expect(activity.jobs.value.single.bitrate, isNull);
      activity.start(id);
      activity.resolved(id, 'youtube', 129);
      activity.progress(id, 40, 100);
      activity.finish(id, true);
      expect(activity.jobs.value.single.resolvedSource, 'youtube');
      expect(activity.jobs.value.single.bitrate, 129);
      expect(activity.jobs.value.single.quality, '160');
    },
  );

  test('individual cancellation cannot cancel a shared playlist token', () {
    final activity = DownloadActivity();
    final batch = DownloadCancellation();
    final individual = DownloadCancellation();
    final batchId = activity.begin(
      {'title': 'Batch track'},
      batch,
      canCancel: false,
    );
    final trackId = activity.begin({'title': 'Single'}, individual);
    expect(activity.cancel(batchId), isFalse);
    expect(batch.isCancelled, isFalse);
    expect(activity.cancel(trackId), isTrue);
    expect(individual.isCancelled, isTrue);
    activity.finish(trackId, false);
    expect(activity.jobs.value.first.stage, DownloadStage.cancelled);
    activity.finish(batchId, false);
    expect(activity.jobs.value.last.stage, DownloadStage.failed);
  });

  test(
    'progress is bounded and finished history preserves active transfers',
    () {
      final activity = DownloadActivity();
      final active = activity.begin({
        'title': 'Active',
      }, DownloadCancellation());
      activity.start(active);
      activity.progress(active, 50, 100);
      expect(activity.jobs.value.single.progress, .5);
      activity.progress(active, 120, 100);
      expect(activity.jobs.value.single.progress, 1);
      for (var i = 0; i < 35; i++) {
        final id = activity.begin({'title': '$i'}, DownloadCancellation());
        activity.finish(id, true);
      }
      expect(activity.jobs.value.length, 31);
      expect(activity.jobs.value.last.id, active);
      activity.clearFinished();
      expect(activity.jobs.value.single.id, active);
    },
  );

  test(
    'quality invalidation keeps provider pin but drops prepared metadata',
    () {
      final song = {
        'forceSource': 'youtube',
        'resolvedSource': 'youtube',
        'resolvedBitrate': 160,
        '_preloadedStreamUrl': 'old',
        '_preloadedStreamMetadata': {'resolvedSource': 'youtube'},
      };
      clearSongPreparedStreams(song);
      expect(song, {'forceSource': 'youtube'});
    },
  );

  test(
    'most played is ranked by count with recent tie order, excluding unplayed',
    () {
      final recent = [
        {'ytid': 'new', 'listeningCount': 2},
        {'ytid': 'unplayed'},
        {'ytid': 'popular', 'listeningCount': '12'},
        {'ytid': 'older', 'listeningCount': 2},
        {'ytid': 'invalid', 'listeningCount': 'bad'},
      ];
      expect(mostPlayedTracks(recent).map((song) => song['ytid']), [
        'popular',
        'new',
        'older',
      ]);
      expect(recent.first['ytid'], 'new');
    },
  );
}
