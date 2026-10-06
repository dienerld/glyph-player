class SeriesTitle {
  const SeriesTitle(this.name, this.season, this.episode);
  final String name;
  final int season, episode;
}

final _marker = RegExp(r'\s*[Ss](\d+)\s*[Ee](\d+)');

/// Splits `Name S01E08` into name, season and episode. A name without the
/// marker (or made only of it) is kept whole with season/episode 0.
SeriesTitle parseSeriesName(String raw) {
  final s = raw.trim();
  final m = _marker.firstMatch(s);
  if (m == null || m.start == 0) return SeriesTitle(s, 0, 0);
  return SeriesTitle(
    s.substring(0, m.start).trim(),
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
  );
}
