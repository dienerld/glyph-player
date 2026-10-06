class MovieTitle {
  const MovieTitle(this.title, this.year, this.tags);
  final String title;
  final int? year;
  final List<String> tags;
}

final _trailingTag = RegExp(r'\s*\[([^\]]+)\]\s*$');
final _trailingYear = RegExp(r'\s*\((\d{4})\)\s*$');

/// Splits `Title (2019) [4K]` into title, year and trailing tags.
/// A result that would leave the title empty keeps the original name.
MovieTitle parseMovieTitle(String name) {
  var rest = name.trim();
  final tags = <String>[];
  while (true) {
    final m = _trailingTag.firstMatch(rest);
    if (m == null || m.start == 0) break;
    tags.insert(0, m.group(1)!);
    rest = rest.substring(0, m.start);
  }
  int? year;
  final y = _trailingYear.firstMatch(rest);
  if (y != null && y.start > 0) {
    year = int.parse(y.group(1)!);
    rest = rest.substring(0, y.start);
  }
  rest = rest.trim();
  if (rest.isEmpty) return MovieTitle(name.trim(), null, const []);
  return MovieTitle(rest, year, tags);
}
