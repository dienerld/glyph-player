import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/features/live/live_home_page.dart';
import 'package:glyph_player/state/providers.dart';

Widget app(Db db) => ProviderScope(
  overrides: [
    dbProvider.overrideWithValue(db),
    appPathsProvider.overrideWithValue(
      const AppPaths(dbPath: ':memory:', downloadPath: '/tmp/x'),
    ),
  ],
  child: const MaterialApp(home: LiveHomePage()),
);

void main() {
  testWidgets('empty DB shows an empty state with a Settings action', (
    t,
  ) async {
    final db = Db.memory();
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    expect(find.text('Nenhum canal ainda'), findsOneWidget);
    expect(find.text('Configurações'), findsWidgets);
    db.close();
  });

  testWidgets('shows one row per group with channel names', (t) async {
    final db = Db.memory();
    final run = db.beginRun();
    db.upsertBatch([
      const StreamEntry(
        type: StreamType.live,
        id: '1',
        name: 'Globo SP',
        group: 'Globo',
        logo: '',
        url: 'http://h/live/U/P/1.ts',
      ),
    ], run);
    db.finishRun(run);
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    expect(find.text('Globo'), findsOneWidget);
    expect(find.text('Globo SP'), findsOneWidget);
    db.close();
  });
}
