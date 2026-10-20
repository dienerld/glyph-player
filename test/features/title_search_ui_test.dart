import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/features/movies/movie_categories_page.dart';
import 'package:glyph_player/features/movies/movie_grid_page.dart';
import 'package:glyph_player/features/series/series_grid_page.dart';
import 'package:glyph_player/features/series/series_home_page.dart';
import 'package:glyph_player/state/providers.dart';

StreamEntry movie(int i, String name, String group) => StreamEntry(
  type: StreamType.movie,
  id: '$i',
  name: name,
  group: group,
  logo: '',
  url: 'http://h/movie/U/P/$i.mp4',
);

StreamEntry episode(int i, String series, String group) => StreamEntry(
  type: StreamType.series,
  id: '$i',
  name: '$series S01E01',
  group: group,
  logo: '',
  url: 'http://h/series/U/P/$i.mp4',
  seriesName: series,
  season: 1,
  episode: 1,
);

Db seed(List<StreamEntry> items) {
  final db = Db.memory();
  final run = db.beginRun();
  db.upsertBatch(items, run);
  db.finishRun(run);
  return db;
}

Widget host(Db db, Widget home) => ProviderScope(
  overrides: [dbProvider.overrideWithValue(db)],
  child: MaterialApp(home: home),
);

Future<void> type(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField), text);
  await t.pump(const Duration(milliseconds: 350));
  await t.pumpAndSettle();
}

void main() {
  final movies = [
    movie(1, 'Ação Máxima', 'Filmes | Ação'),
    movie(2, 'A Grande Aventura', 'Filmes | Aventura'),
    movie(3, 'Coração Valente', 'Filmes | Drama'),
    movie(4, 'Máxima Pressão', 'Filmes | Drama'),
  ];

  group('movies', () {
    testWidgets('search inside a category stays in that category', (t) async {
      final db = seed(movies);
      await t.pumpWidget(
        host(db, const MovieGridPage(group: 'Filmes | Drama')),
      );
      await t.pumpAndSettle();
      expect(find.text('Coração Valente'), findsOneWidget);
      await type(t, 'maxima');
      expect(find.text('Máxima Pressão'), findsOneWidget);
      expect(find.text('Ação Máxima'), findsNothing);
      expect(find.text('Coração Valente'), findsNothing);
      await type(t, 'ma');
      expect(find.text('Máxima Pressão'), findsOneWidget);
      expect(find.text('Coração Valente'), findsNothing);
      await type(t, '');
      expect(find.text('Coração Valente'), findsOneWidget);
      db.close();
    });

    testWidgets('global search finds mid-word, accent-free matches', (t) async {
      final db = seed(movies);
      await t.pumpWidget(host(db, const MovieCategoriesPage()));
      await t.pumpAndSettle();
      expect(find.text('Drama'), findsOneWidget);
      await type(t, 'maxi');
      expect(find.text('Ação Máxima'), findsOneWidget);
      expect(find.text('Máxima Pressão'), findsOneWidget);
      expect(find.text('Coração Valente'), findsNothing);
      expect(find.text('Drama'), findsNothing);
      await type(t, 'coracao');
      expect(find.text('Coração Valente'), findsOneWidget);
      db.close();
    });

    testWidgets('one or two letters match the start, clearing restores', (
      t,
    ) async {
      final db = seed(movies);
      await t.pumpWidget(host(db, const MovieCategoriesPage()));
      await t.pumpAndSettle();
      await type(t, 'a');
      expect(find.text('Ação Máxima'), findsOneWidget);
      expect(find.text('A Grande Aventura'), findsOneWidget);
      expect(find.text('Coração Valente'), findsNothing);
      expect(find.text('Máxima Pressão'), findsNothing);
      expect(find.text('Drama'), findsNothing);
      await type(t, 'MA');
      expect(find.text('Máxima Pressão'), findsOneWidget);
      expect(find.text('Ação Máxima'), findsNothing);
      await type(t, 'maxima');
      expect(find.text('Ação Máxima'), findsOneWidget);
      await t.tap(find.byTooltip('Limpar'));
      await t.pumpAndSettle();
      expect(find.text('Drama'), findsOneWidget);
      db.close();
    });

    testWidgets('Esc clears the field', (t) async {
      final db = seed(movies);
      await t.pumpWidget(host(db, const MovieCategoriesPage()));
      await t.pumpAndSettle();
      await type(t, 'maxima');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Drama'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
      db.close();
    });

    testWidgets('no match shows the empty message', (t) async {
      final db = seed(movies);
      await t.pumpWidget(host(db, const MovieCategoriesPage()));
      await t.pumpAndSettle();
      await type(t, 'zzzz');
      expect(find.text('Nenhum resultado para “zzzz”'), findsOneWidget);
      db.close();
    });
  });

  group('series', () {
    final eps = [
      episode(1, 'Chaves Mágicas', 'Streaming A'),
      episode(2, 'Mágico de Oz', 'Streaming B'),
      episode(3, 'Outra Série', 'Streaming B'),
    ];

    testWidgets('search inside a publisher stays in it', (t) async {
      final db = seed(eps);
      await t.pumpWidget(host(db, const SeriesGridPage(group: 'Streaming B')));
      await t.pumpAndSettle();
      await type(t, 'magic');
      expect(find.text('Mágico de Oz'), findsOneWidget);
      expect(find.text('Chaves Mágicas'), findsNothing);
      db.close();
    });

    testWidgets('global search spans publishers; prefix; clear; empty', (
      t,
    ) async {
      final db = seed(eps);
      await t.pumpWidget(host(db, const SeriesHomePage()));
      await t.pumpAndSettle();
      await type(t, 'ma');
      expect(find.text('Mágico de Oz'), findsOneWidget);
      expect(find.text('Chaves Mágicas'), findsNothing);
      await type(t, 'magic');
      expect(find.text('Chaves Mágicas'), findsOneWidget);
      expect(find.text('Mágico de Oz'), findsOneWidget);
      expect(find.text('Outra Série'), findsNothing);
      await type(t, 'qqqq');
      expect(find.text('Nenhum resultado para “qqqq”'), findsOneWidget);
      await t.tap(find.byTooltip('Limpar'));
      await t.pumpAndSettle();
      expect(find.text('Mágico de Oz'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      db.close();
    });
  });
}
