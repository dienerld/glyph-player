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

/// Quality and version tags lists put at the end of a channel name, in the
/// order variants of one channel are shown. `[L]` marks a subtitled feed.
const _tagRank = {
  'SD': 0,
  'HD': 1,
  'FHD': 2,
  '4K': 3,
  '[4K]': 3,
  'UHD': 3,
  'H265': 4,
  'HEVC': 4,
  '[L]': 5,
};

/// Splits `ESPN 2 FHD H265` into the base name `ESPN 2` and the ranks of its
/// trailing tags. The first word always stays in the base name.
(String, List<int>) _variant(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  var end = words.length;
  while (end > 1 && _tagRank.containsKey(words[end - 1].toUpperCase())) {
    end--;
  }
  return (
    words.take(end).join(' '),
    [for (final w in words.skip(end)) _tagRank[w.toUpperCase()]!],
  );
}

/// [naturalCompare] on the base name, so `ESPN FHD` sits next to `ESPN`
/// instead of after `ESPN 10`; variants of one channel then follow
/// [_tagRank], with the untagged name first.
int channelCompare(String a, String b) {
  final (baseA, tagsA) = _variant(a);
  final (baseB, tagsB) = _variant(b);
  final c = naturalCompare(baseA, baseB);
  if (c != 0) return c;
  for (var i = 0; i < tagsA.length && i < tagsB.length; i++) {
    if (tagsA[i] != tagsB[i]) return tagsA[i].compareTo(tagsB[i]);
  }
  final n = tagsA.length.compareTo(tagsB.length);
  return n != 0 ? n : naturalCompare(a, b);
}
