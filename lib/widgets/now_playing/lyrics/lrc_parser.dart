/// Parsed timed line from LRC / synced lyrics.
typedef LrcLine = ({Duration time, String text});

final _lrcLineRegex = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

/// Common LRC variants, repeated timestamps and file-level offset metadata.
List<LrcLine> parseLrcLyrics(String raw) {
  final parsed = <LrcLine>[];
  final offset =
      int.tryParse(
        RegExp(
              r'\[offset:([+-]?\d+)\]',
              caseSensitive: false,
            ).firstMatch(raw)?[1] ??
            '',
      ) ??
      0;
  for (final line in raw.split('\n')) {
    final matches = _lrcLineRegex.allMatches(line).toList();
    if (matches.isEmpty ||
        line.substring(0, matches.first.start).trim().isNotEmpty)
      continue;
    final text = line.substring(matches.last.end).trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final seconds = int.parse(match[2]!);
      if (seconds >= 60) continue;
      final fraction = (match[3] ?? '').padRight(3, '0');
      final ms =
          int.parse(match[1]!) * 60000 +
          seconds * 1000 +
          int.parse(fraction) -
          offset;
      parsed.add((time: Duration(milliseconds: ms < 0 ? 0 : ms), text: text));
    }
  }
  parsed.sort((a, b) => a.time.compareTo(b.time));
  return parsed;
}

Duration? lineEndTime(List<LrcLine> lines, int index, Duration songDuration) {
  if (index < 0 || index >= lines.length) return null;
  if (index + 1 < lines.length) return lines[index + 1].time;
  if (songDuration > Duration.zero) return songDuration;
  return lines[index].time + const Duration(seconds: 8);
}
