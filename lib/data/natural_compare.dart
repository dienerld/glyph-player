final _chunks = RegExp(r'\d+|\D+');

/// Orders names the way people read them: digit runs compare as numbers and
/// text ignores case, so `Canal 2` comes before `Canal 10`.
int naturalCompare(String a, String b) {
  final x = _chunks.allMatches(a).map((m) => m[0]!).toList();
  final y = _chunks.allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final nx = int.tryParse(x[i]), ny = int.tryParse(y[i]);
    final c = nx != null && ny != null
        ? nx.compareTo(ny)
        : x[i].toLowerCase().compareTo(y[i].toLowerCase());
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}
