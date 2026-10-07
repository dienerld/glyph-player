import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/features/movies/movie_categories_page.dart';
import 'package:glyph_player/features/shared/section_tile.dart';

void main() {
  test(
    'section tints stay in the Glyph purple-to-wine range and are muted',
    () {
      for (var i = 0; i < 300; i++) {
        final hsl = HSLColor.fromColor(sectionTint('Categoria $i | ${i * 7}'));
        expect(hsl.hue, inInclusiveRange(270, 350), reason: 'key $i');
        expect(hsl.saturation, lessThanOrEqualTo(0.35), reason: 'key $i');
        expect(hsl.lightness, lessThanOrEqualTo(0.25), reason: 'key $i');
      }
    },
  );

  test('the same key always gets the same tint', () {
    expect(sectionTint('Filmes | Drama'), sectionTint('Filmes | Drama'));
  });

  test('different categories are not all the same colour', () {
    final tints = {
      for (final k in ['Drama', 'Acao', 'Terror', 'Comedia', 'Crime'])
        sectionTint(k),
    };
    expect(tints.length, greaterThan(2));
  });

  test('a movie group with no name is labelled instead of rendering blank', () {
    expect(categoryLabel(''), 'Sem categoria');
    expect(categoryLabel('Filmes | Drama'), 'Drama');
    expect(categoryLabel('Filmes Adultos'), 'Filmes Adultos');
  });
}
