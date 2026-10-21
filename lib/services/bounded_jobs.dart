/// Shares unfinished work without evicting jobs that are still running.
class BoundedJobs<K, V> {
  BoundedJobs({required this.capacity});
  final int capacity;
  final _jobs = <K, Future<V?>>{};
  Future<V?> run(K key, Future<V?> Function() load) {
    final existing = _jobs[key];
    if (existing != null) return existing;
    if (_jobs.length >= capacity) return Future.value();
    late final Future<V?> work;
    work = Future<V?>.sync(load).whenComplete(() {
      if (identical(_jobs[key], work)) _jobs.remove(key);
    });
    _jobs[key] = work;
    return work;
  }

  Future<void> drain() async {
    await Future.wait(_jobs.values.toList());
  }
}
