import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/content_filter.dart';

void main() {
  test('adult groups are detected', () {
    for (final g in [
      'Filmes Adultos',
      'Hentai [adultos]',
      'Adultos LGBT',
      'Canais | Adultos',
      'XXX',
    ]) {
      expect(isAdultGroup(g), isTrue, reason: g);
    }
  });

  test('regular groups are not adult', () {
    for (final g in ['Filmes | Drama', 'Globo', 'Filmes | Infantil', '']) {
      expect(isAdultGroup(g), isFalse, reason: g);
    }
  });
}
