import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:sqlite3/sqlite3.dart';

var _n = 0;

StreamEntry movie(String name, {String group = 'Filmes'}) => StreamEntry(
  type: StreamType.movie,
  id: 'm${_n++}',
  name: name,
  group: group,
  logo: '',
  url: 'http://h/movie/U/P/$_n.mp4',
);

StreamEntry ep(String series, int e, {String group = 'Netflix'}) => StreamEntry(
  type: StreamType.series,
  id: 's${_n++}',
  name: 'Episódio Especial $e',
  group: group,
  logo: '',
  url: 'http://h/series/U/P/$_n.mp4',
  seriesName: series,
  season: 1,
  episode: e,
);

void load(Db db, List<StreamEntry> es) {
  final run = db.beginRun();
  db.upsertBatch(es, run);
  db.finishRun(run);
}

List<String> movies(Db db, String q, {String? group}) =>
    db.moviesPage(group, SortOrder.az, query: q).map((c) => c.name).toList();

void main() {
  late Db db;
  setUp(() {
    db = Db.memory();
    load(db, [
      movie('Matrix'),
      movie('Ação Total'),
      movie('O Poderoso Chefão', group: 'Clássicos'),
      movie('MATRIX Reloaded', group: 'Clássicos'),
      movie('Acapulco'),
      movie('Brinquedo "Assassino" (1988)'),
      movie('Sexo XXX', group: 'Adultos XXX'),
      ep('Dark', 1),
      ep('Dark', 2),
      ep('Dark', 1, group: 'Séries | Netflix'),
      ep('Darkwing Duck', 1, group: 'Desenhos'),
      ep('Breaking Bad', 1),
    ]);
  });
  tearDown(() => db.close());

  group('moviesPage query', () {
    test('ignores case and accents in both directions', () {
      expect(movies(db, 'acao'), ['Ação Total']);
      expect(movies(db, 'AÇÃO'), ['Ação Total']);
      expect(movies(db, 'chefao'), ['O Poderoso Chefão']);
    });

    test('matches mid-word substrings', () {
      expect(movies(db, 'trix'), ['Matrix', 'MATRIX Reloaded']);
      expect(movies(db, 'oder'), ['O Poderoso Chefão']);
      expect(movies(db, 'o poder'), ['O Poderoso Chefão']);
    });

    test('scopes to one group or all of them', () {
      expect(movies(db, 'matrix', group: 'Filmes'), ['Matrix']);
      expect(movies(db, 'matrix', group: 'Clássicos'), ['MATRIX Reloaded']);
      expect(movies(db, 'matrix'), ['Matrix', 'MATRIX Reloaded']);
    });

    test('one or two characters match the start of the title only', () {
      // 'Matrix' and 'O Poderoso Chefão' contain an 'a' but do not start
      // with one.
      expect(movies(db, 'a'), ['Acapulco', 'Ação Total']);
      expect(movies(db, 'Á'), ['Acapulco', 'Ação Total']);
      expect(movies(db, 'aç'), ['Acapulco', 'Ação Total']);
      expect(movies(db, 'AC'), ['Acapulco', 'Ação Total']);
      expect(movies(db, 'ma'), ['Matrix', 'MATRIX Reloaded']);
      expect(movies(db, 'ma', group: 'Filmes'), ['Matrix']);
      expect(movies(db, '  m  '), ['Matrix', 'MATRIX Reloaded']);
      expect(movies(db, 'o '), ['O Poderoso Chefão']);
      expect(movies(db, 'z'), isEmpty);
    });

    test('an empty query does not filter', () {
      final all = db.moviesPage('Filmes', SortOrder.az).map((c) => c.name);
      expect(movies(db, '', group: 'Filmes'), all);
      expect(movies(db, '   ', group: 'Filmes'), all);
    });

    test('LIKE wildcards in a short query are plain text', () {
      for (final q in ['%', '_', r'\', '"', "'", '%%', 'a_', r'a\']) {
        expect(movies(db, q), isEmpty, reason: q);
      }
    });

    test('prefix search keeps sort and paging', () {
      expect(db.moviesPage(null, SortOrder.za, query: 'a').map((c) => c.name), [
        'Ação Total',
        'Acapulco',
      ]);
      expect(
        db.moviesPage(null, SortOrder.recent, query: 'ma').map((c) => c.name),
        ['MATRIX Reloaded', 'Matrix'],
      );
      expect(
        db
            .moviesPage(null, SortOrder.az, query: 'a', limit: 1, offset: 1)
            .map((c) => c.name),
        ['Ação Total'],
      );
    });

    test('quotes and FTS operators are plain text', () {
      for (final q in [
        '"assassino"',
        'assassino"',
        '"""',
        'a*b',
        'NOT AND OR',
        'title:x',
        '(1988)',
        "o'brien",
        '^mat',
        'x - y',
      ]) {
        expect(() => movies(db, q), returnsNormally, reason: q);
      }
      expect(movies(db, '"assassino"'), ['Brinquedo "Assassino" (1988)']);
      expect(movies(db, '(1988)'), ['Brinquedo "Assassino" (1988)']);
    });

    test('keeps sort and paging with a query', () {
      expect(
        db
            .moviesPage(null, SortOrder.za, query: 'trix')
            .map((c) => c.name)
            .toList(),
        ['MATRIX Reloaded', 'Matrix'],
      );
      expect(
        db
            .moviesPage(null, SortOrder.recent, query: 'trix')
            .map((c) => c.name)
            .toList(),
        ['MATRIX Reloaded', 'Matrix'],
      );
      final p1 = db.moviesPage(null, SortOrder.az, query: 'trix', limit: 1);
      final p2 = db.moviesPage(
        null,
        SortOrder.az,
        query: 'trix',
        limit: 1,
        offset: 1,
      );
      expect([...p1, ...p2].map((c) => c.name), ['Matrix', 'MATRIX Reloaded']);
    });

    test('hideAdult drops adult groups', () {
      expect(movies(db, 'sexo'), ['Sexo XXX']);
      expect(
        db.moviesPage(null, SortOrder.az, query: 'sexo', hideAdult: true),
        isEmpty,
      );
      expect(
        db.moviesPage(null, SortOrder.az, hideAdult: true).map((c) => c.group),
        isNot(contains('Adultos XXX')),
      );
    });
  });

  group('seriesPage query', () {
    List<(String, String, int)> series(String q, {String? group}) => db
        .seriesPage(group, SortOrder.az, query: q)
        .map((s) => (s.group, s.name, s.episodes))
        .toList();

    test('matches the series name, one row per (group, series)', () {
      expect(series('dark'), [
        ('Netflix', 'Dark', 2),
        ('Séries | Netflix', 'Dark', 1),
        ('Desenhos', 'Darkwing Duck', 1),
      ]);
      expect(series('ARKW'), [('Desenhos', 'Darkwing Duck', 1)]);
    });

    test('does not match episode titles', () {
      expect(series('especial'), isEmpty);
    });

    test('scopes to one group', () {
      expect(series('dark', group: 'Netflix'), [('Netflix', 'Dark', 2)]);
    });

    test('one or two characters match the start of the name only', () {
      expect(series('da'), [
        ('Netflix', 'Dark', 2),
        ('Séries | Netflix', 'Dark', 1),
        ('Desenhos', 'Darkwing Duck', 1),
      ]);
      expect(series('DA', group: 'Netflix'), [('Netflix', 'Dark', 2)]);
      expect(series('b'), [('Netflix', 'Breaking Bad', 1)]);
      expect(series('a'), isEmpty); // 'Dark' has an 'a', not at the start
      final p2 = db.seriesPage(null, SortOrder.az, query: 'd', offset: 2);
      expect(p2.map((s) => s.name), ['Darkwing Duck']);
    });

    test('all categories without a query keeps one row per group', () {
      expect(db.seriesPage(null, SortOrder.az).length, 4);
    });

    test('keeps sort and paging with a query', () {
      final za = db.seriesPage(null, SortOrder.za, query: 'dark');
      expect(za.first.name, 'Darkwing Duck');
      final recent = db.seriesPage(null, SortOrder.recent, query: 'dark');
      expect(recent.first.name, 'Darkwing Duck');
      final p2 = db.seriesPage(
        null,
        SortOrder.az,
        query: 'dark',
        limit: 2,
        offset: 2,
      );
      expect(p2.map((s) => s.name), ['Darkwing Duck']);
    });

    test('quotes do not throw', () {
      expect(() => series('"da"rk"'), returnsNormally);
    });
  });

  test('a new import replaces the indexed titles', () {
    load(db, [movie('Interestelar')]);
    expect(movies(db, 'trix'), isEmpty);
    expect(movies(db, 'stela'), ['Interestelar']);
    expect(db.seriesPage(null, SortOrder.az, query: 'dark'), isEmpty);
  });

  group('migration', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('titles'));
    tearDown(() => tmp.delete(recursive: true));

    test('builds the title index on a database created without it', () {
      final path = '${tmp.path}/app.db';
      final first = Db.open(path);
      load(first, [movie('Matrix'), ep('Dark', 1)]);
      first.close();

      final raw = sqlite3.open(path);
      raw.execute('DROP TABLE titles_fts');
      raw.close();

      final reopened = Db.open(path);
      addTearDown(reopened.close);
      expect(movies(reopened, 'atri'), ['Matrix']);
      expect(
        reopened.seriesPage(null, SortOrder.az, query: 'ark').single.name,
        'Dark',
      );
    });

    test('rebuilds an index created before prefix search', () {
      final path = '${tmp.path}/app.db';
      final first = Db.open(path);
      load(first, [movie('Matrix'), ep('Dark', 1)]);
      first.close();

      final raw = sqlite3.open(path);
      raw.execute('''
        DROP TABLE titles_fts;
        CREATE VIRTUAL TABLE titles_fts USING fts5(
          title, kind UNINDEXED, grp UNINDEXED, last UNINDEXED,
          tokenize='trigram remove_diacritics 1');
        INSERT INTO titles_fts(rowid, title, kind, grp, last)
          SELECT rowid, name, 'movie', '', rowid FROM streams
          WHERE type='movie';
      ''');
      raw.close();

      final reopened = Db.open(path);
      addTearDown(reopened.close);
      expect(movies(reopened, 'm'), ['Matrix']);
      expect(movies(reopened, 'atri'), ['Matrix']);
      expect(
        reopened.seriesPage(null, SortOrder.az, query: 'd').single.name,
        'Dark',
      );
    });

    test('opening an empty database leaves the index empty', () {
      final empty = Db.open('${tmp.path}/empty.db');
      addTearDown(empty.close);
      expect(empty.moviesPage(null, SortOrder.az, query: 'abc'), isEmpty);
    });
  });
}
