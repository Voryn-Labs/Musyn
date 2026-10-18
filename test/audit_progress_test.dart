import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/playlist_download_service.dart';

void main() {
  test(
    'idle progress is released after the UI detaches, never while listening',
    () async {
      final service = OfflinePlaylistService();
      final notifier = service.getProgressNotifier('audit-test');
      void listener() {}
      notifier.addListener(listener);
      service.cleanupProgressNotifier('audit-test');
      expect(service.downloadProgressNotifiers['audit-test'], same(notifier));
      notifier.removeListener(listener);
      await Future<void>.delayed(Duration.zero);
      expect(
        service.downloadProgressNotifiers.containsKey('audit-test'),
        isFalse,
      );
    },
  );
  test('completion releases a notifier with no UI listeners', () {
    final service = OfflinePlaylistService();
    service.getProgressNotifier('audit-unobserved');
    service.cleanupProgressNotifier('audit-unobserved');
    expect(
      service.downloadProgressNotifiers.containsKey('audit-unobserved'),
      isFalse,
    );
  });
}
