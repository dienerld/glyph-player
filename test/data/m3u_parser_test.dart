import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/m3u_parser.dart';
import 'package:glyph_player/data/stream_entry.dart';

Future<List<StreamEntry>> parse(List<String> lines) =>
    parseM3u(Stream.fromIterable(lines)).toList();

void main() {
  test('parses a live entry and strips the Canais prefix', () async {
    final r = await parse([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="" tvg-name="Globo SP" tvg-logo="http://x/l.png" group-title="Canais | Globo",Globo SP',
      'http://h/live/U/P/1234.ts',
    ]);
    expect(r, hasLength(1));
    expect(r[0].type, StreamType.live);
    expect(r[0].id, '1234');
    expect(r[0].name, 'Globo SP');
    expect(r[0].group, 'Globo');
    expect(r[0].logo, 'http://x/l.png');
    expect(r[0].url, 'http://h/live/U/P/1234.ts');
  });

  test('name with commas is taken after the attributes', () async {
    final r = await parse([
      '#EXTINF:-1 tvg-id="" tvg-name="A, B" tvg-logo="" group-title="G",A, B, C',
      'http://h/live/U/P/9.ts',
    ]);
    expect(r.single.name, 'A, B, C');
    expect(r.single.logo, '');
  });

  test('CRLF-trimmed lines, movie and series types by URL path', () async {
    final r = await parse([
      '#EXTINF:-1 tvg-id="" tvg-name="F (2020)" tvg-logo="" group-title="Filmes | Drama",F (2020)\r',
      'http://h/movie/U/P/77.mp4\r',
      '#EXTINF:-1 tvg-id="" tvg-name="S S01E01" tvg-logo="" group-title="Series | Netflix",S S01E01',
      'http://h/series/U/P/88.mp4',
    ]);
    expect(r.map((e) => e.type), [StreamType.movie, StreamType.series]);
    expect(r.map((e) => e.id), ['77', '88']);
  });

  test('EXTINF without URL and unknown URL path are skipped', () async {
    final r = await parse([
      '#EXTINF:-1 tvg-id="" tvg-name="Orphan" tvg-logo="" group-title="G",Orphan',
      '#EXTINF:-1 tvg-id="" tvg-name="Other" tvg-logo="" group-title="G",Other',
      'http://h/other/U/P/5.ts',
      '#EXTINF:-1 tvg-id="" tvg-name="Ok" tvg-logo="" group-title="G",Ok',
      'http://h/live/U/P/6.ts',
    ]);
    expect(r.map((e) => e.id), ['6']);
  });

  test('empty tvg-name falls back to the text after the comma', () async {
    final r = await parse([
      '#EXTINF:-1 tvg-id="" tvg-name="" tvg-logo="" group-title="G",Real Name',
      'http://h/live/U/P/3.ts',
    ]);
    expect(r.single.name, 'Real Name');
  });

  test('series entries carry series name, season and episode', () async {
    final r = await parse([
      '#EXTINF:-1 tvg-id="" tvg-name="Dark S02E03" tvg-logo="" group-title="Series | Netflix",Dark S02E03',
      'http://h/series/U/P/5.mp4',
      '#EXTINF:-1 tvg-id="" tvg-name="Globo SP" tvg-logo="" group-title="Globo",Globo SP',
      'http://h/live/U/P/6.ts',
    ]);
    expect((r[0].seriesName, r[0].season, r[0].episode), ('Dark', 2, 3));
    expect((r[1].seriesName, r[1].season, r[1].episode), ('', 0, 0));
  });
}
