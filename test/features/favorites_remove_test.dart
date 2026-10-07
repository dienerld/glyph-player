import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/playlist_url_store.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/features/shell/app_shell.dart';
import 'package:glyph_player/state/providers.dart';

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
    const StreamEntry(
      type: StreamType.live,
      id: '1',
      name: 'Globo SP',
      group: 'Globo',
      logo: '',
      url: 'http://h/live/U/P/1.ts',
    ),
    const StreamEntry(
      type: StreamType.movie,
      id: '2',
      name: 'Palmer (2021)',
      group: 'Filmes | Drama',
      logo: '',
      url: 'http://h/movie/U/P/2.mp4',
    ),
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

/// Moves a mouse pointer over [finder] so hover-only controls appear.
Future<void> hover(WidgetTester t, Finder finder) async {
  // Tests default to a touch platform, where hover highlights are off; desktop
  // (the real app) uses the traditional mode.
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  final g = await t.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  await g.moveTo(t.getCenter(finder));
  await t.pumpAndSettle(); // the mouse tracker applies hover after a frame
}

void main() {
  testWidgets('Live: "Remover da lista" takes a channel out of Recentes', (
    t,
  ) async {
    final db = seeded();
    db.markWatched('live', '1', DateTime.utc(2026, 1, 1));
    await t.pumpWidget(app(db));
    await t.pumpAndSettle();
    expect(find.text('Recentes'), findsOneWidget);
    await t.tap(find.byTooltip('Remover da lista'));
    await t.pumpAndSettle();
    expect(find.text('Recentes'), findsNothing);
    expect(db.recents(), isEmpty);
    db.close();
  });

  testWidgets(
    'Live: the star on a card favorites the channel and shows Favoritos',
    (t) async {
      final db = seeded();
      await t.pumpWidget(app(db));
      await t.pumpAndSettle();
      expect(find.text('Favoritos'), findsNothing);
      await hover(t, find.text('Globo SP'));
      await t.tap(find.byTooltip('Favoritar'));
      await t.pumpAndSettle();
      expect(db.isFavorite('live', '1'), isTrue);
      expect(find.text('Favoritos'), findsOneWidget);
      db.close();
    },
  );

  testWidgets(
    'Filmes: "Remover da lista" takes a movie out of Continuar assistindo',
    (t) async {
      final db = seeded();
      db.saveProgress('movie', '2', 600000, 7200000, DateTime.utc(2026, 1, 3));
      await t.pumpWidget(app(db));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Filmes'));
      await t.pumpAndSettle();
      expect(find.text('Continuar assistindo'), findsOneWidget);
      await t.tap(find.byTooltip('Remover da lista'));
      await t.pumpAndSettle();
      expect(find.text('Continuar assistindo'), findsNothing);
      expect(db.continueWatching(), isEmpty);
      db.close();
    },
  );

  testWidgets(
    'Filmes: the star favorites a movie and a Favoritos row appears',
    (t) async {
      final db = seeded();
      await t.pumpWidget(app(db));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Filmes'));
      await t.pumpAndSettle();
      expect(find.text('Favoritos'), findsNothing);
      await t.tap(find.text('Drama'));
      await t.pumpAndSettle();
      await hover(t, find.text('Palmer'));
      await t.tap(find.byTooltip('Favoritar'));
      await t.pumpAndSettle();
      expect(db.isFavorite('movie', '2'), isTrue);
      await t.tap(find.byTooltip('Voltar'));
      await t.pumpAndSettle();
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('Palmer'), findsOneWidget);
      db.close();
    },
  );
}
