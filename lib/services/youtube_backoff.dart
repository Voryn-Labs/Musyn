/// Respect a provider throttle without rotating through more clients or songs.
class YoutubeBackoff {
  YoutubeBackoff({
    DateTime Function()? now,
    this.duration = const Duration(seconds: 30),
  }) : now = now ?? DateTime.now;
  final DateTime Function() now;
  final Duration duration;
  DateTime? _until;
  bool get active => _until?.isAfter(now()) ?? false;
  void limited() {
    _until = now().add(duration);
  }
}
