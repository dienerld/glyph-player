import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/features/series/series_grid_page.dart';
import 'package:glyph_player/state/providers.dart';

StreamEntry episode(int i) => StreamEntry(
  type: StreamType.series,
  id: '$i',
  name: 'Serie ${i.toString().padLeft(3, '0')} S01E01',
  group: 'Streaming',
  logo: '',
  url: 'http://h/series/U/P/$i.mp4',
  seriesName: 'Serie ${i.toString().padLeft(3, '0')}',
  season: 1,
  episode: 1,
);

Future<Db> seeded(int n) async {
  final db = Db.memory();
  final run = db.beginRun();
  db.upsertBatch([for (var i = 0; i < n; i++) episode(i)], run);
  db.finishRun(run);
  return db;
}

Widget app(Db db) => ProviderScope(
  overrides: [dbProvider.overrideWithValue(db)],
  child: const MaterialApp(home: SeriesGridPage(group: 'Streaming')),
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
    expect(db.setting('series_sort'), 'za');
    expect(find.text('Serie 004'), findsOneWidget);
    db.close();
  });

  testWidgets('scrolling to the end of a long category loads more', (t) async {
    final db = await seeded(130);
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    final container = ProviderScope.containerOf(
      t.element(find.byType(SeriesGridPage)),
    );
    int count() => container
        .read(seriesPageProvider(const GridScope.group('Streaming')))
        .value!
        .items
        .length;
    expect(count(), gridPageSize);
    await t.drag(find.byType(GridView), const Offset(0, -100000));
    await t.pumpAndSettle();
    expect(count(), gridPageSize * 2);
    await t.drag(find.byType(GridView), const Offset(0, -100000));
    await t.pumpAndSettle();
    expect(count(), 130);
    db.close();
  });
}
