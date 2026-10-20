import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/importer.dart';
import 'package:glyph_player/data/tmdb_info.dart';

const info = TmdbInfo(id: 9, posterPath: '/p.jpg', rating: 8.1, overview: 'R');

String entry(String id, String name) =>
    '#EXTINF:-1 tvg-id="" tvg-name="$name" tvg-logo="" group-title="Filmes | G",$name\r\n'
    'http://h/movie/U/P/$id.mp4\r\n';

void main() {
  final t0 = DateTime(2026, 1, 1);

  test('a found row round-trips and never expires', () {
    final db = Db.memory();
    addTearDown(db.close);
    db.putTmdb(TmdbKind.movie, 'duna', info, t0, year: 2021);
    final c = db.tmdbCached(TmdbKind.movie, 'duna', year: 2021)!;
    expect(c.info, info);
    expect(c.fetchedAt, t0);
    expect(c.isFresh(t0.add(const Duration(days: 3650))), isTrue);
  });

  test('a not-found row is fresh for 30 days only', () {
    final db = Db.memory();
    addTearDown(db.close);
    db.putTmdb(TmdbKind.series, 'nada', null, t0);
    final c = db.tmdbCached(TmdbKind.series, 'nada')!;
    expect(c.info, isNull);
    expect(c.isFresh(t0.add(const Duration(days: 29))), isTrue);
    expect(c.isFresh(t0.add(tmdbNotFoundTtl)), isFalse);
  });

  test('kind, title and year are separate keys; writes replace', () {
    final db = Db.memory();
    addTearDown(db.close);
    db.putTmdb(TmdbKind.movie, 'duna', info, t0, year: 2021);
    expect(db.tmdbCached(TmdbKind.movie, 'duna'), isNull);
    expect(db.tmdbCached(TmdbKind.series, 'duna', year: 2021), isNull);
    db.putTmdb(TmdbKind.movie, 'duna', null, t0, year: 2021);
    expect(db.tmdbCached(TmdbKind.movie, 'duna', year: 2021)!.info, isNull);
  });

  test('clearTmdbCache forgets everything', () {
    final db = Db.memory();
    addTearDown(db.close);
    db.putTmdb(TmdbKind.movie, 'duna', info, t0);
    db.putTmdb(TmdbKind.series, 'dark', null, t0);
    db.clearTmdbCache();
    expect(db.tmdbCached(TmdbKind.movie, 'duna'), isNull);
    expect(db.tmdbCached(TmdbKind.series, 'dark'), isNull);
  });

  test('importing a playlist leaves the TMDB cache intact', () async {
    final tmp = await Directory.systemTemp.createTemp('tmdbimp');
    addTearDown(() => tmp.delete(recursive: true));
    final dbPath = '${tmp.path}/t.db';
    final db = Db.open(dbPath);
    db.putTmdb(TmdbKind.movie, 'duna', info, t0, year: 2021);
    db.putTmdb(TmdbKind.series, 'dark', null, t0);
    db.close();
    final f = File('${tmp.path}/l.m3u')
      ..writeAsStringSync('#EXTM3U\r\n${entry('1', 'Duna (2021)')}');
    expect(await importFile(dbPath: dbPath, file: f), 1);
    final after = Db.open(dbPath);
    addTearDown(after.close);
    expect(after.tmdbCached(TmdbKind.movie, 'duna', year: 2021)!.info, info);
    expect(after.tmdbCached(TmdbKind.series, 'dark'), isNotNull);
  });
}
