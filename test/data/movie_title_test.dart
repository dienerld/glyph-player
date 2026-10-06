import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/movie_title.dart';

void main() {
  test('extracts the trailing year', () {
    final t = parseMovieTitle('Palmer (2021)');
    expect(t.title, 'Palmer');
    expect(t.year, 2021);
    expect(t.tags, isEmpty);
  });

  test('extracts trailing tags after the year, in order', () {
    final t = parseMovieTitle('Meu Amigo Enzo (2019) [4K] [L]');
    expect(t.title, 'Meu Amigo Enzo');
    expect(t.year, 2019);
    expect(t.tags, ['4K', 'L']);
  });

  test('a year-like number inside the title is not the year', () {
    final t = parseMovieTitle('Blade Runner 2049 (2017)');
    expect(t.title, 'Blade Runner 2049');
    expect(t.year, 2017);
  });

  test('no year keeps the whole name; leading tags stay in the title', () {
    final t = parseMovieTitle('[XXXX] Filme457');
    expect(t.title, '[XXXX] Filme457');
    expect(t.year, isNull);
  });

  test('a name that is only a year-tag does not become empty', () {
    expect(parseMovieTitle('(2020)').title, '(2020)');
  });
}
