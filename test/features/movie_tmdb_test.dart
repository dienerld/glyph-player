import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/tmdb_info.dart';
import 'package:glyph_player/features/movies/movie_card.dart';
import 'package:glyph_player/features/movies/movie_categories_page.dart';
import 'package:glyph_player/features/movies/movie_details_page.dart';
import 'package:glyph_player/features/movies/movie_grid_page.dart';
import 'package:glyph_player/features/shared/tmdb_attribution.dart';

import 'tmdb_ui_support.dart';

const _logo = 'http://img.test/rocky.jpg';
const _overview = 'Um ex-presidiário volta para casa.';

String _card(String path) => tmdbImageUrl(path, TmdbImageSize.card);
String _big(String path) => tmdbImageUrl(path, TmdbImageSize.details);

void main() {
  late Db db;
  late FakeTmdb tmdb;
  late FakeThumbs thumbs;

  setUp(() {
    db = seedDb([
      movieEntry('1', 'Palmer (2021)'),
      movieEntry('2', 'Rocky (1976) [4K]', logo: _logo),
      movieEntry('3', 'Sem Dados (2000)'),
    ]);
    tmdb = FakeTmdb({
      'Palmer': tmdbResult(
        1,
        poster: '/palmer.jpg',
        rating: 7.43,
        overview: _overview,
      ),
      'Rocky': tmdbResult(2, poster: '/rocky.jpg', rating: 8.1),
    });
    thumbs = FakeThumbs();
  });
  tearDown(() => db.close());

  Future<void> pumpGrid(WidgetTester t, {bool withKey = true}) async {
    await t.pumpWidget(
      tmdbHost(
        db,
        tmdb,
        thumbs,
        const MovieGridPage(group: 'Filmes | Drama'),
        withKey: withKey,
      ),
    );
    await t.pumpAndSettle();
  }

  Finder player(String name) => find.text(playerText(name));
  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(MovieCard));

  group('without a key', () {
    testWidgets('cards stay as they are and a tap opens the player', (t) async {
      await pumpGrid(t, withKey: false);
      expect(tmdb.sent, isEmpty);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      // Only the list's own logo is ever fetched.
      expect(thumbs.requested, [_logo]);

      await t.tap(find.text('Palmer'));
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsOneWidget);
      expect(find.byType(MovieDetailsPage), findsNothing);
      expect(find.text('Assistir'), findsNothing);
      expect(tmdb.sent, isEmpty);
    });
  });

  group('card', () {
    testWidgets('shows the TMDB poster and rating once there is data', (
      t,
    ) async {
      await pumpGrid(t);
      // Palmer has no logo: TMDB's poster fills in. Rating with a comma.
      expect(thumbs.requested, contains(_card('/palmer.jpg')));
      expect(find.text('7,4'), findsOneWidget);
      expect(find.text('8,1'), findsOneWidget);
      // One chip per movie with a vote; "Sem Dados" has none.
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.text('Sem Dados'), findsOneWidget);
      // Only titles and years go to TMDB.
      expect(tmdb.sent, unorderedEquals(['Palmer', 'Rocky', 'Sem Dados']));
    });

    testWidgets("the list's logo wins over the TMDB poster", (t) async {
      await pumpGrid(t);
      expect(thumbs.requested, contains(_logo));
      expect(thumbs.requested, isNot(contains(_card('/rocky.jpg'))));
      // The rating still comes from TMDB.
      expect(find.text('8,1'), findsOneWidget);
    });

    testWidgets('the rating arriving does not move anything', (t) async {
      tmdb.gate = Completer<void>();
      await pumpGrid(t);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      final size = t.getSize(card('Palmer'));
      final title = t.getTopLeft(find.text('Palmer'));
      final year = t.getTopLeft(find.text('2021'));
      final tag = t.getTopLeft(find.text('4K'));

      tmdb.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text('7,4'), findsOneWidget);
      expect(t.getSize(card('Palmer')), size);
      expect(t.getTopLeft(find.text('Palmer')), title);
      expect(t.getTopLeft(find.text('2021')), year);
      expect(t.getTopLeft(find.text('4K')), tag);
    });

    testWidgets('a failed lookup leaves the plain typographic card', (t) async {
      tmdb.status = 500;
      await pumpGrid(t);
      expect(find.text('Palmer'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(thumbs.requested, [_logo]);
    });

    testWidgets('only the cards that were built ask TMDB', (t) async {
      db.close();
      db = seedDb([
        for (var i = 0; i < 150; i++)
          movieEntry('$i', 'Filme ${i.toString().padLeft(3, '0')}'),
      ]);
      await pumpGrid(t);
      expect(tmdb.sent, isNotEmpty);
      expect(tmdb.sent.length, lessThan(gridPageSize));
    });
  });

  group('details', () {
    Future<void> openDetails(WidgetTester t, String title) async {
      await t.tap(find.text(title));
      await t.pumpAndSettle();
    }

    testWidgets('a tap with a key opens the details, not the player', (
      t,
    ) async {
      await pumpGrid(t);
      await openDetails(t, 'Palmer');
      expect(find.byType(MovieDetailsPage), findsOneWidget);
      expect(player('Palmer (2021)'), findsNothing);
      // Title, year, rating, synopsis, button and the TMDB credit.
      expect(
        find.descendant(
          of: find.byType(MovieDetailsPage),
          matching: find.text('Palmer'),
        ),
        findsOneWidget,
      );
      expect(find.text('2021'), findsWidgets);
      expect(find.text('7,4'), findsWidgets);
      expect(find.text(_overview), findsOneWidget);
      expect(find.text('Assistir'), findsOneWidget);
      expect(find.byType(TmdbAttribution), findsOneWidget);
      // Bigger poster than the card's.
      expect(thumbs.requested, contains(_big('/palmer.jpg')));
    });

    testWidgets('Assistir opens the player and back returns to the details', (
      t,
    ) async {
      await pumpGrid(t);
      await openDetails(t, 'Palmer');
      await t.tap(find.text('Assistir'));
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsOneWidget);

      await t.pageBack();
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsNothing);
      expect(find.byType(MovieDetailsPage), findsOneWidget);
      expect(find.text('Assistir'), findsOneWidget);

      await t.tap(find.byTooltip('Voltar'));
      await t.pumpAndSettle();
      expect(find.byType(MovieDetailsPage), findsNothing);
      expect(find.byType(MovieCard), findsWidgets);
    });

    testWidgets('Enter plays and Esc goes back', (t) async {
      await pumpGrid(t);
      await openDetails(t, 'Palmer');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(MovieDetailsPage), findsNothing);
      expect(find.byType(MovieCard), findsWidgets);
    });

    testWidgets('without data it still has the title and Assistir', (t) async {
      await pumpGrid(t);
      await openDetails(t, 'Sem Dados');
      expect(find.byType(MovieDetailsPage), findsOneWidget);
      expect(find.text('Sem resumo disponível.'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing); // no rating
      expect(find.byType(TmdbAttribution), findsOneWidget);
      await t.tap(find.text('Assistir'));
      await t.pumpAndSettle();
      expect(player('Sem Dados (2000)'), findsOneWidget);
    });

    testWidgets('while loading it shows a placeholder and Assistir', (t) async {
      tmdb.gate = Completer<void>();
      await pumpGrid(t);
      await openDetails(t, 'Palmer');
      expect(find.text('Buscando o resumo…'), findsOneWidget);
      expect(find.text('Assistir'), findsOneWidget);

      tmdb.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Buscando o resumo…'), findsNothing);
      expect(find.text(_overview), findsOneWidget);
    });

    testWidgets('the star on the details toggles the favorite', (t) async {
      await pumpGrid(t);
      await openDetails(t, 'Palmer');
      await t.tap(find.byTooltip('Favoritar'));
      await t.pumpAndSettle();
      expect(db.isFavorite('movie', '1'), isTrue);
      expect(find.byTooltip('Remover dos favoritos'), findsWidgets);
    });
  });

  group('which taps open the details', () {
    Future<void> pumpHome(WidgetTester t) async {
      db.saveProgress('movie', '1', 60000, 600000, DateTime.utc(2026, 1, 1));
      db.setFavorite('movie', '2', true);
      await t.pumpWidget(
        tmdbHost(db, tmdb, thumbs, const MovieCategoriesPage()),
      );
      await t.pumpAndSettle();
    }

    testWidgets('Continuar assistindo goes straight to the player', (t) async {
      await pumpHome(t);
      expect(find.text('Continuar assistindo'), findsOneWidget);
      await t.tap(find.text('Palmer'));
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsOneWidget);
      expect(find.byType(MovieDetailsPage), findsNothing);
    });

    testWidgets('Favoritos opens the details', (t) async {
      await pumpHome(t);
      expect(find.text('Favoritos'), findsOneWidget);
      await t.tap(find.text('Rocky'));
      await t.pumpAndSettle();
      expect(find.byType(MovieDetailsPage), findsOneWidget);
      expect(player('Rocky (1976) [4K]'), findsNothing);
    });

    testWidgets('search results open the details', (t) async {
      await t.pumpWidget(
        tmdbHost(db, tmdb, thumbs, const MovieCategoriesPage()),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'palmer');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      await t.tap(find.text('Palmer'));
      await t.pumpAndSettle();
      expect(find.byType(MovieDetailsPage), findsOneWidget);
    });

    testWidgets('with no key even Favoritos and search open the player', (
      t,
    ) async {
      db.setFavorite('movie', '2', true);
      await t.pumpWidget(
        tmdbHost(db, tmdb, thumbs, const MovieCategoriesPage(), withKey: false),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Rocky'));
      await t.pumpAndSettle();
      expect(player('Rocky (1976) [4K]'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'palmer');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      await t.tap(find.text('Palmer'));
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsOneWidget);
      expect(find.byType(MovieDetailsPage), findsNothing);
      expect(tmdb.sent, isEmpty);
    });
  });
}
