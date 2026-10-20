import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/playlist_url_store.dart';
import 'package:glyph_player/data/tmdb_info.dart';
import 'package:glyph_player/features/settings/settings_page.dart';
import 'package:glyph_player/state/providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _NoStore implements PlaylistUrlStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String u) async {}
}

Future<ProviderContainer> pump(
  WidgetTester t,
  Db db,
  http.Client client,
) async {
  t.view.physicalSize = const Size(1000, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      playlistUrlStoreProvider.overrideWithValue(_NoStore()),
      tmdbHttpClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await t.pump();
  return c;
}

Finder keyField() => find.widgetWithText(TextField, 'Chave da API do TMDB');

void main() {
  final ok = MockClient((_) async => http.Response('{"success":true}', 200));

  testWidgets('saving persists the key and enables TMDB; empty removes it', (
    t,
  ) async {
    final db = Db.memory();
    addTearDown(db.close);
    final c = await pump(t, db, ok);
    expect(c.read(tmdbEnabledProvider), isFalse);

    await t.enterText(keyField(), '  abc123  ');
    await t.tap(find.text('Salvar chave'));
    await t.pump();
    expect(db.setting('tmdb_key'), 'abc123');
    expect(c.read(tmdbEnabledProvider), isTrue);

    await t.enterText(keyField(), '');
    await t.tap(find.text('Salvar chave'));
    await t.pump();
    expect(c.read(tmdbEnabledProvider), isFalse);
    expect((db.setting('tmdb_key') ?? '').isEmpty, isTrue);
  });

  testWidgets('test button is disabled with an empty field', (t) async {
    final db = Db.memory();
    addTearDown(db.close);
    await pump(t, db, ok);
    final b = t.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Testar chave'),
    );
    expect(b.onPressed, isNull);
  });

  for (final (label, client, msg) in [
    ('valid', ok, 'Chave válida'),
    (
      'invalid',
      MockClient((_) async => http.Response('{}', 401)),
      'Chave inválida',
    ),
    (
      'offline',
      MockClient((_) async => throw const SocketException('down')),
      'Sem conexão com o TMDB',
    ),
  ]) {
    testWidgets('Testar chave shows $label', (t) async {
      final db = Db.memory();
      addTearDown(db.close);
      await pump(t, db, client);
      await t.enterText(keyField(), 'k');
      await t.pump();
      await t.tap(find.text('Testar chave'));
      await t.pumpAndSettle();
      expect(find.text(msg), findsOneWidget);
    });
  }

  testWidgets('clear cache empties the table', (t) async {
    final db = Db.memory();
    addTearDown(db.close);
    db.putTmdb(
      TmdbKind.movie,
      'duna',
      const TmdbInfo(id: 1, posterPath: '/p', rating: 8, overview: 'r'),
      DateTime(2026),
    );
    await pump(t, db, ok);
    expect(db.tmdbCached(TmdbKind.movie, 'duna'), isNotNull);
    final b = find.text('Limpar cache de metadados');
    await t.ensureVisible(b);
    await t.tap(b);
    await t.pump();
    expect(db.tmdbCached(TmdbKind.movie, 'duna'), isNull);
    expect(find.text('Cache de metadados limpo.'), findsOneWidget);
  });
}
