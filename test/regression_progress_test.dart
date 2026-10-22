import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/playlist_download_service.dart';

void main() {
  test(
    'idle progress is released after the UI detaches, never while listening',
    () async {
      final service = OfflinePlaylistService();
      final notifier = service.getProgressNotifier('regression-test');
      void listener() {}
      notifier.addListener(listener);
      service.cleanupProgressNotifier('regression-test');
      expect(
        service.downloadProgressNotifiers['regression-test'],
        same(notifier),
      );
      notifier.removeListener(listener);
      await Future<void>.delayed(Duration.zero);
      expect(
        service.downloadProgressNotifiers.containsKey('regression-test'),
        isFalse,
      );
    },
  );
  test('completion releases a notifier with no UI listeners', () {
    final service = OfflinePlaylistService();
    service.getProgressNotifier('regression-unobserved');
    service.cleanupProgressNotifier('regression-unobserved');
    expect(
      service.downloadProgressNotifiers.containsKey('regression-unobserved'),
      isFalse,
    );
  });
}
