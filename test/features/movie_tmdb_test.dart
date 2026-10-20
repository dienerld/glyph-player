import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/tmdb_info.dart';
import 'package:glyph_player/features/movies/movie_card.dart';
import 'package:glyph_player/features/movies/movie_categories_page.dart';
import 'package:glyph_player/features/movies/movie_details_panel.dart';
import 'package:glyph_player/features/movies/movie_grid_page.dart';
import 'package:glyph_player/features/shared/tmdb_attribution.dart';
import 'package:glyph_player/state/providers.dart';

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
      expect(find.byType(MovieDetailsPanel), findsNothing);
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

  group('details panel', () {
    final panel = find.byType(MovieDetailsPanel);
    Finder inPanel(Finder f) => find.descendant(of: panel, matching: f);

    Future<void> open(WidgetTester t, String title) async {
      await t.tap(card(title));
      await t.pumpAndSettle();
    }

    testWidgets('a tap with a key opens the details in the grid', (t) async {
      await pumpGrid(t);
      await open(t, 'Palmer');
      expect(panel, findsOneWidget);
      expect(player('Palmer (2021)'), findsNothing);
      // Title, year, rating, synopsis, button and the TMDB credit.
      expect(inPanel(find.text('Palmer')), findsOneWidget);
      expect(inPanel(find.text('2021')), findsOneWidget);
      expect(inPanel(find.text('7,4')), findsOneWidget);
      expect(inPanel(find.text(_overview)), findsOneWidget);
      expect(inPanel(find.text('Assistir')), findsOneWidget);
      expect(inPanel(find.byType(TmdbAttribution)), findsOneWidget);
      // Bigger poster than the card's.
      expect(thumbs.requested, contains(_big('/palmer.jpg')));
    });

    testWidgets('Assistir opens the player and back keeps the panel', (
      t,
    ) async {
      await pumpGrid(t);
      await open(t, 'Palmer');
      await t.tap(find.text('Assistir'));
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsOneWidget);

      await t.pageBack();
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsNothing);
      expect(panel, findsOneWidget);
      expect(find.text('Assistir'), findsOneWidget);
    });

    testWidgets('Assistir has the focus: Enter plays; Esc closes', (t) async {
      await pumpGrid(t);
      await open(t, 'Palmer');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      // The focus is back on the card.
      expect(_focusedIn(t, card('Palmer')), isTrue);
      expect(find.byType(MovieCard), findsNWidgets(3));
    });

    testWidgets('tapping the open card or the close button closes it', (
      t,
    ) async {
      await pumpGrid(t);
      await open(t, 'Palmer');
      await open(t, 'Palmer');
      expect(panel, findsNothing);

      await open(t, 'Palmer');
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      expect(_focusedIn(t, card('Palmer')), isTrue);
    });

    testWidgets('one panel at a time: another card moves it', (t) async {
      await pumpGrid(t);
      await open(t, 'Palmer');
      await open(t, 'Rocky');
      expect(panel, findsOneWidget);
      expect(inPanel(find.text('Rocky')), findsOneWidget);
      expect(inPanel(find.text('Palmer')), findsNothing);
    });

    testWidgets('without data it still has the title and Assistir', (t) async {
      await pumpGrid(t);
      await open(t, 'Sem Dados');
      expect(inPanel(find.text(noOverviewText)), findsOneWidget);
      expect(inPanel(find.byIcon(Icons.star_rounded)), findsNothing);
      expect(inPanel(find.byType(TmdbAttribution)), findsOneWidget);
      await t.tap(find.text('Assistir'));
      await t.pumpAndSettle();
      expect(player('Sem Dados (2000)'), findsOneWidget);
    });

    testWidgets('while loading it shows a placeholder and Assistir', (t) async {
      tmdb.gate = Completer<void>();
      await pumpGrid(t);
      await open(t, 'Palmer');
      expect(find.text(loadingOverviewText), findsOneWidget);
      expect(find.text('Assistir'), findsOneWidget);

      tmdb.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text(loadingOverviewText), findsNothing);
      expect(find.text(_overview), findsOneWidget);
    });

    testWidgets('the star on the panel toggles the favorite', (t) async {
      await pumpGrid(t);
      await open(t, 'Palmer');
      await t.tap(inPanel(find.byTooltip('Favoritar')));
      await t.pumpAndSettle();
      expect(db.isFavorite('movie', '1'), isTrue);
      expect(inPanel(find.byTooltip('Remover dos favoritos')), findsOneWidget);
      // The card's star follows.
      expect(
        find.descendant(
          of: card('Palmer'),
          matching: find.byTooltip('Remover dos favoritos'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('changing the sort or searching closes it', (t) async {
      await pumpGrid(t);
      await open(t, 'Palmer');
      await t.tap(find.byTooltip('Ordenar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Z → A'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(panel, findsNothing);

      await open(t, 'Palmer');
      expect(panel, findsOneWidget);
      await t.enterText(find.byType(TextField), 'pal');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      expect(card('Palmer'), findsOneWidget);
    });
  });

  group('panel layout', () {
    final panel = find.byType(MovieDetailsPanel);

    /// Nine movies, A → Z: "Filme 1" .. "Filme 9".
    Future<void> pumpNine(WidgetTester t, Size window) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = window;
      addTearDown(t.view.reset);
      db.close();
      db = seedDb([for (var i = 1; i <= 9; i++) movieEntry('$i', 'Filme $i')]);
      await pumpGrid(t);
    }

    testWidgets('opens below the row of the card and pushes the rest down', (
      t,
    ) async {
      // 800 wide: 4 columns.
      await pumpNine(t, const Size(800, 900));
      final before = {
        for (final n in [1, 2, 4, 5, 9]) n: t.getRect(card('Filme $n')),
      };
      expect(before[5]!.top, greaterThan(before[1]!.bottom)); // next row

      await t.tap(card('Filme 2'));
      await t.pumpAndSettle();
      final p = t.getRect(panel);
      // Full width, between the first row and the second.
      expect(p.left, before[1]!.left);
      expect(p.right, before[4]!.right);
      expect(p.top, greaterThan(before[2]!.bottom));
      // The first row stays; the rows after it move down by the panel.
      for (final n in [1, 2, 4]) {
        expect(t.getRect(card('Filme $n')), before[n]);
      }
      final row2 = t.getRect(card('Filme 5'));
      expect(row2.top, greaterThan(p.bottom));
      expect(
        row2.top - before[5]!.top,
        moreOrLessEquals(p.bottom - before[2]!.bottom, epsilon: 0.01),
      );
      expect(t.getRect(card('Filme 9')).top, greaterThan(row2.bottom));
    });

    testWidgets('on a short window the synopsis scrolls inside the panel', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(800, 450);
      addTearDown(t.view.reset);
      final long = List.filled(120, 'Uma longa sinopse.').join(' ');
      tmdb = FakeTmdb({'Palmer': tmdbResult(1, overview: long)});
      await pumpGrid(t);
      await t.tap(card('Palmer'));
      await t.pumpAndSettle();
      // Capped: no taller than the grid's visible area allows.
      expect(t.getSize(panel).height, lessThanOrEqualTo(360));
      expect(
        find.ancestor(
          of: find.text(long),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Assistir'));
      await t.pumpAndSettle();
      expect(player('Palmer (2021)'), findsOneWidget);
    });

    testWidgets('a narrower window keeps the panel under its card', (t) async {
      // 1200 wide: 6 columns, "Filme 5" in the first row.
      await pumpNine(t, const Size(1200, 900));
      await t.tap(card('Filme 5'));
      await t.pumpAndSettle();
      final state = t.state(panel);
      var p = t.getRect(panel);
      expect(p.top, greaterThan(t.getRect(card('Filme 5')).bottom));
      expect(t.getRect(card('Filme 7')).top, greaterThan(p.bottom));

      // 800 wide: 4 columns, "Filme 5" moves to the second row.
      t.view.physicalSize = const Size(800, 900);
      await t.pumpAndSettle();
      p = t.getRect(panel);
      final five = t.getRect(card('Filme 5'));
      expect(five.top, greaterThan(t.getRect(card('Filme 1')).bottom));
      expect(p.top, greaterThan(five.bottom));
      expect(t.getRect(card('Filme 9')).top, greaterThan(p.bottom));
      // Same panel, not a new one opening again.
      expect(t.state(panel), same(state));
    });

    testWidgets('loading more pages works with a panel open', (t) async {
      db.close();
      db = seedDb([
        for (var i = 0; i < 130; i++)
          movieEntry('$i', 'Filme ${i.toString().padLeft(3, '0')}'),
      ]);
      await pumpGrid(t);
      final container = ProviderScope.containerOf(
        t.element(find.byType(MovieGridPage)),
      );
      int count() => container
          .read(moviesPageProvider(const GridScope.group('Filmes | Drama')))
          .value!
          .items
          .length;
      expect(count(), gridPageSize);

      await t.tap(card('Filme 001'));
      await t.pumpAndSettle();
      expect(panel, findsOneWidget);
      final state = t.state(panel);
      final scroll = find.byType(CustomScrollView);
      await t.drag(scroll, const Offset(0, -100000));
      await t.pumpAndSettle();
      expect(count(), gridPageSize * 2);
      await t.drag(scroll, const Offset(0, -100000));
      await t.pumpAndSettle();
      expect(count(), 130);

      // Back at the top the panel is still open under its card.
      await t.drag(scroll, const Offset(0, 100000));
      await t.pumpAndSettle();
      expect(panel, findsOneWidget);
      expect(
        t.getRect(panel).top,
        greaterThan(t.getRect(card('Filme 001')).bottom),
      );
      // Kept while out of view: it does not open (and grab the focus) again.
      expect(t.state(panel), same(state));
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
      expect(find.byType(MovieDetailsPanel), findsNothing);
    });

    testWidgets('Favoritos opens the details below its row', (t) async {
      // Tall enough to see the categories under the panel.
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(900, 1200);
      addTearDown(t.view.reset);
      await pumpHome(t);
      expect(find.text('Favoritos'), findsOneWidget);
      await t.tap(card('Rocky'));
      await t.pumpAndSettle();
      final panel = find.byType(MovieDetailsPanel);
      expect(panel, findsOneWidget);
      expect(player('Rocky (1976) [4K]'), findsNothing);
      final p = t.getRect(panel);
      expect(p.top, greaterThan(t.getRect(card('Rocky')).bottom));
      expect(t.getRect(find.text('Drama')).top, greaterThan(p.bottom));

      // Esc closes it and the card has the focus again.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(panel, findsNothing);
      expect(_focusedIn(t, card('Rocky')), isTrue);

      // Assistir plays.
      await t.tap(card('Rocky'));
      await t.pumpAndSettle();
      await t.tap(find.text('Assistir'));
      await t.pumpAndSettle();
      expect(player('Rocky (1976) [4K]'), findsOneWidget);
    });

    testWidgets('search results open the details', (t) async {
      await t.pumpWidget(
        tmdbHost(db, tmdb, thumbs, const MovieCategoriesPage()),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'palmer');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      await t.tap(card('Palmer'));
      await t.pumpAndSettle();
      expect(find.byType(MovieDetailsPanel), findsOneWidget);
      expect(player('Palmer (2021)'), findsNothing);
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
      expect(find.byType(MovieDetailsPanel), findsNothing);
      expect(tmdb.sent, isEmpty);
    });
  });
}

/// Whether the keyboard focus is on [target] or inside it.
bool _focusedIn(WidgetTester t, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final el = t.element(target);
  if (focused == el) return true;
  var found = false;
  focused.visitAncestorElements((e) {
    found = e == el;
    return !found;
  });
  return found;
}
