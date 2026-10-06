import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/playlist_url_store.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/features/settings/settings_page.dart';
import 'package:glyph_player/features/shell/app_shell.dart';
import 'package:glyph_player/state/providers.dart';

StreamEntry movie(String id, String name, String group) => StreamEntry(
  type: StreamType.movie,
  id: id,
  name: name,
  group: group,
  logo: '',
  url: 'http://h/movie/U/P/$id.mp4',
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
    movie('1', 'Palmer (2021)', 'Filmes | Drama'),
    movie('2', 'Rocky (1976) [4K]', 'Filmes | Drama'),
    movie('3', 'Duro de Matar (1988)', 'Filmes | Acao'),
    movie('4', 'Filme Escondido', 'Filmes Adultos'),
  ], run);
  db.finishRun(run);
  return db;
}

Widget app(Db db, Widget home) => ProviderScope(
  overrides: [
    dbProvider.overrideWithValue(db),
    appPathsProvider.overrideWithValue(
      const AppPaths(dbPath: ':memory:', downloadPath: '/tmp/x'),
    ),
    playlistUrlStoreProvider.overrideWithValue(_NoStore()),
  ],
  child: MaterialApp(home: home),
);

void main() {
  testWidgets('rail switches to Filmes and lists category tiles without the prefix', (t) async {
    final db = seeded();
    await t.pumpWidget(app(db, const AppShell()));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filmes'));
    await t.pumpAndSettle();
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Acao'), findsOneWidget);
    expect(find.text('2 filmes'), findsOneWidget);
    expect(find.text('Filmes Adultos'), findsNothing);
    db.close();
  });

  testWidgets('choosing a category opens a grid with parsed titles, years and tags', (t) async {
    final db = seeded();
    await t.pumpWidget(app(db, const AppShell()));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filmes'));
    await t.pumpAndSettle();
    await t.tap(find.text('Drama'));
    await t.pumpAndSettle();
    expect(find.text('Palmer'), findsOneWidget);
    expect(find.text('2021'), findsOneWidget);
    expect(find.text('Rocky'), findsOneWidget);
    expect(find.text('4K'), findsOneWidget);
    expect(find.text('Duro de Matar'), findsNothing);
    db.close();
  });

  testWidgets('Filmes without any movie shows an empty state', (t) async {
    final db = Db.memory();
    await t.pumpWidget(app(db, const AppShell()));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Filmes'));
    await t.pumpAndSettle();
    expect(find.text('Nenhum filme ainda'), findsOneWidget);
    db.close();
  });

  testWidgets('Settings switch turns adult content on', (t) async {
    final db = seeded();
    await t.pumpWidget(app(db, const SettingsPage()));
    await t.pumpAndSettle();
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(db.setting('show_adult'), '1');
    db.close();
  });
}
