import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';

StreamEntry e(
  String id,
  String name,
  String group, {
  StreamType t = StreamType.live,
}) => StreamEntry(
  type: t,
  id: id,
  name: name,
  group: group,
  logo: '',
  url: 'http://h/${t.name}/U/P/$id.ts',
);

void main() {
  late Db db;
  setUp(() => db = Db.memory());
  tearDown(() => db.close());

  void load(List<StreamEntry> es) {
    final run = db.beginRun();
    db.upsertBatch(es, run);
    db.finishRun(run);
  }

  test('groups keep provider order and only include live', () {
    load([
      e('1', 'A', 'Globo'),
      e('2', 'B', 'Esportes'),
      e('3', 'C', 'Globo'),
      e('4', 'Movie', 'Filmes', t: StreamType.movie),
    ]);
    expect(db.groups('live').map((g) => g.name), ['Globo', 'Esportes']);
    expect(db.channels('live', 'Globo').map((c) => c.id), ['1', '3']);
  });

  test('second run updates rows and removes vanished ones', () {
    load([e('1', 'Old', 'G'), e('2', 'Gone', 'G')]);
    load([e('1', 'New', 'G')]);
    final ch = db.channels('live', 'G');
    expect(ch.map((c) => c.name), ['New']);
  });

  test('FTS5 search is prefix, accent-insensitive and live-only', () {
    load([
      e('1', 'Programação Esportiva', 'G'),
      e('2', 'Filme Esporte', 'F', t: StreamType.movie),
    ]);
    expect(db.search('live', 'programa').map((c) => c.id), ['1']);
    expect(db.search('live', 'programacao').map((c) => c.id), ['1']);
  });

  test('search with FTS special characters does not throw', () {
    load([e('1', 'Globo', 'G')]);
    for (final q in ['"', '*', '-', '(', 'a:b', 'AND', '   ', '"glo"']) {
      expect(() => db.search('live', q), returnsNormally, reason: q);
    }
    expect(db.search('live', '   '), isEmpty);
  });

  test(
    'favorites and recents survive a re-import and hide vanished streams',
    () {
      load([e('1', 'A', 'G'), e('2', 'B', 'G')]);
      db.setFavorite('live', '1', true);
      db.markWatched('live', '2', DateTime.utc(2026, 1, 1));
      db.markWatched('live', '1', DateTime.utc(2026, 1, 2));
      load([e('1', 'A', 'G')]);
      expect(db.favorites().map((c) => c.id), ['1']);
      expect(db.recents().map((c) => c.id), ['1']);
      db.setFavorite('live', '1', false);
      expect(db.isFavorite('live', '1'), isFalse);
    },
  );

  test('groups report counts per type, in provider order', () {
    load([
      e('1', 'A', 'Filmes | Drama', t: StreamType.movie),
      e('2', 'B', 'Filmes | Acao', t: StreamType.movie),
      e('3', 'C', 'Filmes | Drama', t: StreamType.movie),
      e('4', 'Live', 'Globo'),
    ]);
    final g = db.groups('movie');
    expect(g.map((x) => x.name), ['Filmes | Drama', 'Filmes | Acao']);
    expect(g.map((x) => x.count), [2, 1]);
    expect(db.channels('movie', 'Filmes | Drama').map((c) => c.id), ['1', '3']);
  });

  test('search is scoped to the requested type', () {
    load([
      e('1', 'Programa Live', 'G'),
      e('2', 'Programa Filme', 'F', t: StreamType.movie),
    ]);
    expect(db.search('movie', 'programa').map((c) => c.id), ['2']);
  });

  test('settings round-trip and default to null', () {
    expect(db.setting('adult'), isNull);
    db.setSetting('adult', '1');
    expect(db.setting('adult'), '1');
    db.setSetting('adult', '0');
    expect(db.setting('adult'), '0');
  });

  test(
    'progress is stored and continue-watching skips finished or barely started',
    () {
      load([
        e('1', 'Mid', 'F', t: StreamType.movie),
        e('2', 'Done', 'F', t: StreamType.movie),
        e('3', 'Start', 'F', t: StreamType.movie),
        e('4', 'Older', 'F', t: StreamType.movie),
      ]);
      db.saveProgress('movie', '1', 600000, 7200000, DateTime.utc(2026, 1, 3));
      db.saveProgress('movie', '2', 7100000, 7200000, DateTime.utc(2026, 1, 4));
      db.saveProgress('movie', '3', 5000, 7200000, DateTime.utc(2026, 1, 5));
      db.saveProgress('movie', '4', 900000, 5400000, DateTime.utc(2026, 1, 2));
      final p = db.progressOf('movie', '1');
      expect(p!.positionMs, 600000);
      expect(p.durationMs, 7200000);
      expect(db.progressOf('movie', '99'), isNull);
      expect(db.continueWatching().map((c) => c.id), ['1', '4']);
      db.saveProgress('movie', '1', 700000, 7200000, DateTime.utc(2026, 1, 9));
      expect(db.progressOf('movie', '1')!.positionMs, 700000);
    },
  );
}
