import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/features/movies/movie_grid_page.dart';
import 'package:glyph_player/state/providers.dart';

StreamEntry movie(int i) => StreamEntry(
  type: StreamType.movie,
  id: '$i',
  name: 'Filme ${i.toString().padLeft(3, '0')}',
  group: 'Filmes',
  logo: '',
  url: 'http://h/movie/U/P/$i.mp4',
);

Future<Db> seeded(int n) async {
  final db = Db.memory();
  final run = db.beginRun();
  db.upsertBatch([for (var i = 0; i < n; i++) movie(i)], run);
  db.finishRun(run);
  return db;
}

Widget app(Db db) => ProviderScope(
  overrides: [dbProvider.overrideWithValue(db)],
  child: const MaterialApp(home: MovieGridPage(group: 'Filmes')),
);

void main() {
  testWidgets('sort menu lists three options and choosing one persists it', (
    t,
  ) async {
    final db = await seeded(5);
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Ordenar'));
    await t.pumpAndSettle();
    expect(find.text('Adicionados recentes'), findsOneWidget);
    expect(find.text('A → Z'), findsOneWidget);
    expect(find.text('Z → A'), findsOneWidget);
    await t.tap(find.text('Z → A'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(db.setting('movie_sort'), 'za');
    expect(find.text('Filme 004'), findsOneWidget);
    db.close();
  });

  testWidgets('scrolling to the end of a long category loads more', (t) async {
    final db = await seeded(130);
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    final container = ProviderScope.containerOf(
      t.element(find.byType(MovieGridPage)),
    );
    int count() => container
        .read(moviesPageProvider(const GridScope.group('Filmes')))
        .value!
        .items
        .length;
    expect(count(), gridPageSize);
    await t.drag(find.byType(CustomScrollView), const Offset(0, -100000));
    await t.pumpAndSettle();
    expect(count(), gridPageSize * 2);
    await t.drag(find.byType(CustomScrollView), const Offset(0, -100000));
    await t.pumpAndSettle();
    expect(count(), 130);
    db.close();
  });

  testWidgets('changing the sort scrolls back to the top', (t) async {
    final db = await seeded(130);
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    await t.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await t.pumpAndSettle();
    final grid = t.widget<CustomScrollView>(find.byType(CustomScrollView));
    expect(grid.controller!.offset, greaterThan(0));
    await t.tap(find.byTooltip('Ordenar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Z → A'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(
      t
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!
          .offset,
      0,
    );
    db.close();
  });
}
