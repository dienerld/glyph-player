import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/state/providers.dart';

StreamEntry movie(int i) => StreamEntry(
  type: StreamType.movie,
  id: '$i',
  name: 'Filme ${i.toString().padLeft(3, '0')}',
  group: 'Filmes',
  logo: '',
  url: 'http://h/movie/U/P/$i.mp4',
);

const filmes = GridScope.group('Filmes');

void main() {
  late Db db;
  late ProviderContainer c;
  setUp(() {
    db = Db.memory();
    final run = db.beginRun();
    db.upsertBatch([
      for (var i = 0; i < 70; i++) movie(i),
      const StreamEntry(
        type: StreamType.movie,
        id: 'a',
        name: 'Filme Adulto',
        group: 'Adult',
        logo: '',
        url: 'http://h/movie/U/P/a.mp4',
      ),
    ], run);
    db.finishRun(run);
    c = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    // Keep the autoDispose provider alive for the whole test.
    c.listen(moviesPageProvider(filmes), (_, _) {});
  });
  tearDown(() {
    c.dispose();
    db.close();
  });

  test('sort preference defaults to az and persists', () {
    expect(c.read(movieSortProvider), SortOrder.az);
    expect(c.read(seriesSortProvider), SortOrder.az);
    c.read(movieSortProvider.notifier).set(SortOrder.recent);
    expect(db.setting('movie_sort'), 'recent');
    final c2 = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    addTearDown(c2.dispose);
    expect(c2.read(movieSortProvider), SortOrder.recent);
    expect(c2.read(seriesSortProvider), SortOrder.az);
  });

  test('loads the first page, then the rest on loadMore', () async {
    final first = await c.read(moviesPageProvider(filmes).future);
    expect(first.items.length, gridPageSize);
    expect(first.hasMore, isTrue);
    expect(first.items.first.name, 'Filme 000');

    final more = c.read(moviesPageProvider(filmes).notifier).loadMore();
    expect(c.read(moviesPageProvider(filmes)).value!.loading, isTrue);
    await more;
    final all = c.read(moviesPageProvider(filmes)).value!;
    expect(all.loading, isFalse);
    expect(all.hasMore, isFalse);
    expect(all.items.map((m) => m.id).toSet().length, 70);

    // Nothing left: further calls change nothing.
    await c.read(moviesPageProvider(filmes).notifier).loadMore();
    expect(c.read(moviesPageProvider(filmes)).value!.items.length, 70);
  });

  test('changing the sort starts over from the first page', () async {
    await c.read(moviesPageProvider(filmes).future);
    await c.read(moviesPageProvider(filmes).notifier).loadMore();
    c.read(movieSortProvider.notifier).set(SortOrder.za);
    final page = await c.read(moviesPageProvider(filmes).future);
    expect(page.items.length, gridPageSize);
    expect(page.items.first.name, 'Filme 069');
  });

  test('a sort change during loadMore drops the stale page', () async {
    await c.read(moviesPageProvider(filmes).future);
    final more = c.read(moviesPageProvider(filmes).notifier).loadMore();
    c.read(movieSortProvider.notifier).set(SortOrder.za);
    await more;
    final page = await c.read(moviesPageProvider(filmes).future);
    expect(page.items.length, gridPageSize);
    expect(page.items.first.name, 'Filme 069');
  });

  group('GridScope', () {
    test('is value-equal', () {
      expect(
        const GridScope(group: 'A', query: 'abc'),
        GridScope.search('abc', group: 'A'),
      );
      expect(
        GridScope.search('abc').hashCode,
        const GridScope(query: 'abc').hashCode,
      );
      expect(const GridScope.group('A'), isNot(const GridScope()));
      expect(const GridScope(query: 'abc'), isNot(GridScope.search('abd')));
    });

    test('search trims; only an empty query is no search', () {
      expect(GridScope.search('   '), const GridScope());
      expect(GridScope.search('', group: 'A'), const GridScope.group('A'));
      expect(GridScope.search(' a '), const GridScope(query: 'a'));
      expect(GridScope.search(' abc '), const GridScope(query: 'abc'));
      expect(GridScope.search(' ').searching, isFalse);
      expect(GridScope.search('a').searching, isTrue);
    });
  });

  test('a query in one group narrows the grid', () async {
    final s = GridScope.search('filme 06', group: 'Filmes');
    c.listen(moviesPageProvider(s), (_, _) {});
    final page = await c.read(moviesPageProvider(s).future);
    expect(page.items.map((m) => m.name), [
      for (var i = 60; i < 70; i++) 'Filme 0$i',
    ]);
    expect(page.hasMore, isFalse);
  });

  test('a query across all categories pages and hides adult groups', () async {
    final s = GridScope.search('filme');
    c.listen(moviesPageProvider(s), (_, _) {});
    final first = await c.read(moviesPageProvider(s).future);
    expect(first.items.length, gridPageSize);
    await c.read(moviesPageProvider(s).notifier).loadMore();
    final all = c.read(moviesPageProvider(s)).value!;
    expect(all.items.length, 70);
    expect(all.items.map((m) => m.group).toSet(), {'Filmes'});

    c.read(showAdultProvider.notifier).set(true);
    await c.read(moviesPageProvider(s).future);
    await c.read(moviesPageProvider(s).notifier).loadMore();
    final withAdult = c.read(moviesPageProvider(s)).value!;
    expect(withAdult.items.length, 71);
  });

  test('a one-letter query lists titles starting with it', () async {
    final s = GridScope.search('f');
    c.listen(moviesPageProvider(s), (_, _) {});
    final first = await c.read(moviesPageProvider(s).future);
    expect(first.items.length, gridPageSize);
    expect(first.hasMore, isTrue);
  });
}
