import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';

StreamEntry movie(String id, String name, {String group = 'Filmes'}) =>
    StreamEntry(
      type: StreamType.movie,
      id: id,
      name: name,
      group: group,
      logo: '',
      url: 'http://h/movie/U/P/$id.mp4',
    );

StreamEntry ep(String id, String series, {String group = 'Netflix'}) =>
    StreamEntry(
      type: StreamType.series,
      id: id,
      name: '$series S1E$id',
      group: group,
      logo: '',
      url: 'http://h/series/U/P/$id.mp4',
      seriesName: series,
      season: 1,
      episode: int.parse(id),
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

  group('moviesPage', () {
    setUp(
      () => load([
        movie('1', 'banana'),
        movie('2', 'Apple'),
        movie('3', 'cherry'),
        movie('4', 'Outra', group: 'Outros'),
        StreamEntry(
          type: StreamType.live,
          id: '5',
          name: 'Aaa',
          group: 'Filmes',
          logo: '',
          url: 'http://h/live/U/P/5.ts',
        ),
      ]),
    );

    List<String> names(SortOrder o) =>
        db.moviesPage('Filmes', o).map((c) => c.name).toList();

    test('az and za ignore case and stay in the movie group', () {
      expect(names(SortOrder.az), ['Apple', 'banana', 'cherry']);
      expect(names(SortOrder.za), ['cherry', 'banana', 'Apple']);
    });

    test('recent puts the newest imported first', () {
      expect(names(SortOrder.recent), ['cherry', 'Apple', 'banana']);
      // A later import keeps old rows' position and adds the new one on top.
      load([
        movie('1', 'banana'),
        movie('2', 'Apple'),
        movie('3', 'cherry'),
        movie('9', 'Novo'),
      ]);
      expect(names(SortOrder.recent), ['Novo', 'cherry', 'Apple', 'banana']);
    });

    for (final order in SortOrder.values) {
      test('pages without gaps or repeats ($order)', () {
        // Repeated names force the rowid tiebreak.
        load([for (var i = 0; i < 130; i++) movie('$i', 'Filme ${i % 7}')]);
        final p1 = db.moviesPage('Filmes', order);
        final p2 = db.moviesPage('Filmes', order, offset: gridPageSize);
        final p3 = db.moviesPage('Filmes', order, offset: 2 * gridPageSize);
        final p4 = db.moviesPage('Filmes', order, offset: 3 * gridPageSize);
        expect([p1.length, p2.length, p3.length, p4.length], [60, 60, 10, 0]);
        final ids = [...p1, ...p2, ...p3].map((c) => c.id).toList();
        expect(ids.toSet().length, 130);
        expect(
          ids,
          db.moviesPage('Filmes', order, limit: 200).map((c) => c.id),
        );
        expect(
          db.moviesPage('Filmes', order, limit: 5, offset: 3).map((c) => c.id),
          ids.sublist(3, 8),
        );
      });
    }
  });

  group('seriesPage', () {
    setUp(
      () => load([
        ep('1', 'dark'),
        ep('2', 'Alias'),
        ep('3', 'dark'),
        ep('4', 'Lost'),
        ep('5', 'Alias'),
        ep('6', 'Outra', group: 'Outros'),
      ]),
    );

    List<String> names(SortOrder o) =>
        db.seriesPage('Netflix', o).map((s) => s.name).toList();

    test('one entry per series, az and za ignore case', () {
      expect(names(SortOrder.az), ['Alias', 'dark', 'Lost']);
      expect(names(SortOrder.za), ['Lost', 'dark', 'Alias']);
      final alias = db.seriesPage('Netflix', SortOrder.az).first;
      expect(alias.episodes, 2);
    });

    test('recent orders by the newest episode of each series', () {
      expect(names(SortOrder.recent), ['Alias', 'Lost', 'dark']);
      load([
        ep('1', 'dark'),
        ep('2', 'Alias'),
        ep('3', 'dark'),
        ep('4', 'Lost'),
        ep('5', 'Alias'),
        ep('7', 'dark'),
        ep('8', 'Nova'),
      ]);
      expect(names(SortOrder.recent), ['Nova', 'dark', 'Alias', 'Lost']);
    });

    for (final order in SortOrder.values) {
      test('pages without gaps or repeats ($order)', () {
        load([
          for (var i = 0; i < 130; i++) ...[
            ep('${2 * i}', 'Serie $i'),
            ep('${2 * i + 1}', 'Serie $i'),
          ],
        ]);
        final p1 = db.seriesPage('Netflix', order);
        final p2 = db.seriesPage('Netflix', order, offset: gridPageSize);
        final p3 = db.seriesPage('Netflix', order, offset: 2 * gridPageSize);
        expect([p1.length, p2.length, p3.length], [60, 60, 10]);
        final all = [...p1, ...p2, ...p3].map((s) => s.name).toList();
        expect(all.toSet().length, 130);
        expect(
          all,
          db.seriesPage('Netflix', order, limit: 200).map((s) => s.name),
        );
        expect(p1.every((s) => s.episodes == 2), isTrue);
      });
    }
  });
}
