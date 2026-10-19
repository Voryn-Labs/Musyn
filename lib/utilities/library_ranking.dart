/// Rank only listened tracks; preserve recency order when play counts tie.
List<Map> mostPlayedTracks(Iterable songs) {
  final indexed =
      songs
          .whereType<Map>()
          .indexed
          .where(
            (entry) => (num.tryParse('${entry.$2['listeningCount']}') ?? 0) > 0,
          )
          .toList()
        ..sort((a, b) {
          final counts = (num.tryParse('${b.$2['listeningCount']}') ?? 0)
              .compareTo(num.tryParse('${a.$2['listeningCount']}') ?? 0);
          return counts == 0 ? a.$1.compareTo(b.$1) : counts;
        });
  return indexed.map((entry) => entry.$2).toList();
}
