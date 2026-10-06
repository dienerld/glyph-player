import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/playlist_url_store.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/features/shell/app_shell.dart';
import 'package:glyph_player/state/providers.dart';

StreamEntry ep(String id, String group, String series, int s, int e) =>
    StreamEntry(
      type: StreamType.series,
      id: id,
      name: '$series S${s}E$e',
      group: group,
      logo: '',
      url: 'http://h/series/U/P/$id.mp4',
      seriesName: series,
      season: s,
      episode: e,
    );

class _NoStore implements PlaylistUrlStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String u) async {}
}

Db seeded() {
  final db = Db.memory();
  final run = db.beginRun();
  db.upsertBatch([
    ep('1', 'Series | Netflix', 'Dark', 1, 1),
    ep('2', 'Series | Netflix', 'Dark', 1, 2),
    ep('3', 'Series | Netflix', 'Dark', 2, 1),
    ep('4', 'Novelas', 'A Gata', 1, 1),
    ep('5', 'Hentai [adultos]', 'Escondida', 1, 1),
  ], run);
  db.finishRun(run);
  return db;
}

Widget app(Db db) => ProviderScope(
  overrides: [
    dbProvider.overrideWithValue(db),
    appPathsProvider.overrideWithValue(
      const AppPaths(dbPath: ':memory:', downloadPath: '/tmp/x'),
    ),
    playlistUrlStoreProvider.overrideWithValue(_NoStore()),
  ],
  child: const MaterialApp(home: AppShell()),
);

Future<void> openSeries(WidgetTester t) async {
  await t.tap(find.byTooltip('Séries'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Séries lists distributors without the prefix and collections as sections',
    (t) async {
      final db = seeded();
      await t.pumpWidget(app(db));
      await t.pumpAndSettle();
      await openSeries(t);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Novelas'), findsOneWidget);
      expect(find.text('Hentai [adultos]'), findsNothing);
      expect(find.text('1 série'), findsWidgets);
      db.close();
    },
  );

  testWidgets(
    'a section opens a grid with seasons per series, and a series page lists episodes',
    (t) async {
      final db = seeded();
      await t.pumpWidget(app(db));
      await t.pumpAndSettle();
      await openSeries(t);
      await t.tap(find.text('Netflix'));
      await t.pumpAndSettle();
      expect(find.text('Dark'), findsWidgets);
      expect(find.text('2 temporadas'), findsOneWidget);
      await t.tap(find.text('2 temporadas'));
      await t.pumpAndSettle();
      expect(find.text('Assistir'), findsOneWidget);
      expect(find.text('T1'), findsOneWidget);
      expect(find.text('T2'), findsOneWidget);
      expect(find.text('E01'), findsOneWidget);
      expect(find.text('E02'), findsOneWidget);
      await t.tap(find.text('T2'));
      await t.pumpAndSettle();
      expect(find.text('E02'), findsNothing);
      db.close();
    },
  );

  testWidgets('the star on the series page toggles the favorite', (t) async {
    final db = seeded();
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    await openSeries(t);
    await t.tap(find.text('Netflix'));
    await t.pumpAndSettle();
    await t.tap(find.text('2 temporadas'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Favoritar'));
    await t.pumpAndSettle();
    expect(db.isSeriesFavorite('Series | Netflix', 'Dark'), isTrue);
    db.close();
  });

  testWidgets(
    'Continue row appears for watched series and "Remover da lista" removes it',
    (t) async {
      final db = seeded();
      db.touchProgress('series', '2', DateTime.utc(2026, 1, 1));
      await t.pumpWidget(app(db));
      await t.pumpAndSettle();
      await openSeries(t);
      expect(find.text('Continuar assistindo'), findsOneWidget);
      await t.tap(find.byTooltip('Remover da lista'));
      await t.pumpAndSettle();
      expect(find.text('Continuar assistindo'), findsNothing);
      expect(db.continueSeries(), isEmpty);
      db.close();
    },
  );

  testWidgets('Séries without any series shows an empty state', (t) async {
    final db = Db.memory();
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    await openSeries(t);
    expect(find.text('Nenhuma série ainda'), findsOneWidget);
    db.close();
  });
}
