/// Runs at most one attempt per enabled provider, preserving the user's order.
/// The transfer owns atomic writes, cancellation and the offline registry.
Future<bool> downloadWithSourceFallback({
  required String preferred,
  required bool saavnEnabled,
  required Future<bool> Function(String source) attempt,
  required bool Function() isCancelled,
  void Function(String source)? onFallback,
}) async {
  final first = switch (preferred) {
    'youtube' => 'youtube',
    'saavn' || 'jiosaavn' => saavnEnabled ? 'saavn' : 'youtube',
    _ => saavnEnabled ? 'saavn' : 'youtube',
  };
  final sources = [
    first,
    if (first == 'saavn') 'youtube' else if (saavnEnabled) 'saavn',
  ];
  for (var index = 0; index < sources.length; index++) {
    if (isCancelled()) return false;
    if (index > 0 ||
        (preferred == 'jiosaavn' || preferred == 'saavn') && first != 'saavn') {
      onFallback?.call(sources[index]);
    }
    if (await attempt(sources[index])) return true;
  }
  return false;
}
