import 'series_title.dart';
import 'stream_entry.dart';

final _attr = RegExp(r'\s*([\w-]+)="([^"]*)"');
const _livePrefix = 'Canais | ';

/// Parses M3U_plus lines into entries. Skips malformed or unknown-type entries.
Stream<StreamEntry> parseM3u(Stream<String> lines) async* {
  String? inf;
  await for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTINF')) {
      inf = line;
      continue;
    }
    if (line.startsWith('#') || inf == null) continue;
    final entry = _entry(inf, line);
    inf = null;
    if (entry != null) yield entry;
  }
}

/// Classic lists tag the type in the path (`/live/`, `/movie/`, `/series/`).
/// `/play/<token>` lists do not: `.../ts` is live, otherwise an `SxxExx`
/// name marks a series episode and anything else is a movie.
StreamType? _type(List<String> path, String name) => switch (path.first) {
  'live' => StreamType.live,
  'movie' => StreamType.movie,
  'series' => StreamType.series,
  'play' when path.length > 2 => StreamType.live,
  'play' =>
    parseSeriesName(name).season > 0 ? StreamType.series : StreamType.movie,
  _ => null,
};

StreamEntry? _entry(String inf, String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.pathSegments.length < 2) return null;
  final attrs = <String, String>{};
  var pos = inf.indexOf(' ');
  if (pos < 0) return null;
  while (true) {
    final m = _attr.matchAsPrefix(inf, pos);
    if (m == null) break;
    attrs[m.group(1)!] = m.group(2)!;
    pos = m.end;
  }
  final comma = inf.indexOf(',', pos);
  var name = comma < 0 ? '' : inf.substring(comma + 1).trim();
  if (name.isEmpty) name = attrs['tvg-name'] ?? '';
  if (name.isEmpty) return null;

  final type = _type(uri.pathSegments, name);
  if (type == null) return null;

  // `/play/<token>/ts` (live) keeps the token in the middle segment.
  final last = uri.pathSegments.first == 'play' && uri.pathSegments.length > 2
      ? uri.pathSegments[1]
      : uri.pathSegments.last;
  final dot = last.lastIndexOf('.');
  final id = dot > 0 ? last.substring(0, dot) : last;

  var group = attrs['group-title'] ?? '';
  if (group.startsWith(_livePrefix)) {
    group = group.substring(_livePrefix.length);
  }

  final series = type == StreamType.series ? parseSeriesName(name) : null;

  return StreamEntry(
    type: type,
    id: id,
    name: name,
    group: group,
    logo: attrs['tvg-logo'] ?? '',
    url: url,
    seriesName: series?.name ?? '',
    season: series?.season ?? 0,
    episode: series?.episode ?? 0,
  );
}
