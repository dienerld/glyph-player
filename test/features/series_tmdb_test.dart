import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/tmdb_info.dart';
import 'package:glyph_player/features/series/series_card.dart';
import 'package:glyph_player/features/series/series_page.dart';

import 'tmdb_ui_support.dart';

const _listPoster = 'http://img.test/dark.jpg';
const _overview = 'Um desaparecimento abre um ciclo de segredos em uma cidade.';

String _card(String path) => tmdbImageUrl(path, TmdbImageSize.card);

void main() {
  late Db db;
  late FakeTmdb tmdb;
  late FakeThumbs thumbs;

  setUp(() {
    db = seedDb([
      episodeEntry('1', 'Dark', 1, 1),
      episodeEntry('2', 'Dark', 1, 2),
    ]);
    tmdb = FakeTmdb({
      'Dark': tmdbResult(
        9,
        poster: '/dark.jpg',
        rating: 8.4,
        overview: _overview,
      ),
    });
    thumbs = FakeThumbs();
  });
  tearDown(() => db.close());

  SeriesSummary summary({String poster = ''}) =>
      SeriesSummary('Series | Netflix', 'Dark', poster, 1, 2);

  Future<void> pumpPage(
    WidgetTester t, {
    String poster = '',
    bool withKey = true,
  }) async {
    await t.pumpWidget(
      tmdbHost(
        db,
        tmdb,
        thumbs,
        SeriesPage(summary: summary(poster: poster)),
        withKey: withKey,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> pumpCard(
    WidgetTester t, {
    String poster = '',
    bool withKey = true,
  }) async {
    await t.pumpWidget(
      tmdbHost(
        db,
        tmdb,
        thumbs,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: seriesCardWidth,
              height: seriesCardHeight,
              child: SeriesCard(summary: summary(poster: poster)),
            ),
          ),
        ),
        withKey: withKey,
      ),
    );
    await t.pumpAndSettle();
  }

  group('series page', () {
    testWidgets('shows the rating and the synopsis from TMDB', (t) async {
      await pumpPage(t);
      expect(find.text('8,4'), findsOneWidget);
      expect(find.text(_overview), findsOneWidget);
      expect(find.text('Assistir'), findsOneWidget);
      expect(tmdb.sent, ['Dark']);
    });

    testWidgets("keeps the list's poster", (t) async {
      await pumpPage(t, poster: _listPoster);
      expect(thumbs.requested, [_listPoster]);
    });

    testWidgets('falls back to the TMDB poster when the list has none', (
      t,
    ) async {
      await pumpPage(t);
      expect(thumbs.requested, [_card('/dark.jpg')]);
    });

    testWidgets('shows nothing extra without a key', (t) async {
      await pumpPage(t, withKey: false);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text(_overview), findsNothing);
      expect(find.text('Assistir'), findsOneWidget);
      expect(tmdb.sent, isEmpty);
      expect(thumbs.requested, isEmpty);
    });

    testWidgets('shows nothing extra when TMDB has no match', (t) async {
      tmdb = FakeTmdb();
      await pumpPage(t);
      expect(tmdb.sent, ['Dark']);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text(_overview), findsNothing);
      expect(find.text('Assistir'), findsOneWidget);
    });

    testWidgets('shows nothing extra when the lookup fails', (t) async {
      tmdb.status = 500;
      await pumpPage(t);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text(_overview), findsNothing);
      expect(find.text('Assistir'), findsOneWidget);
    });
  });

  group('series card', () {
    testWidgets("keeps the list's poster and does not ask TMDB", (t) async {
      await pumpCard(t, poster: _listPoster);
      expect(thumbs.requested, [_listPoster]);
      expect(tmdb.sent, isEmpty);
    });

    testWidgets("uses TMDB's poster only when the list has none", (t) async {
      await pumpCard(t);
      expect(tmdb.sent, ['Dark']);
      expect(thumbs.requested, [_card('/dark.jpg')]);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('without a key it is the monogram, as before', (t) async {
      await pumpCard(t, withKey: false);
      expect(tmdb.sent, isEmpty);
      expect(thumbs.requested, isEmpty);
      expect(find.text('D'), findsOneWidget);
    });
  });
}
