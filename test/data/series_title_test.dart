import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/series_title.dart';

void main() {
  test('splits name, season and episode', () {
    final t = parseSeriesName('Além do Mal S01E08');
    expect(t.name, 'Além do Mal');
    expect(t.season, 1);
    expect(t.episode, 8);
  });

  test('is case and spacing tolerant', () {
    for (final raw in ['Dark s1e2', 'Dark S01 E02', 'Dark   s01e02']) {
      final t = parseSeriesName(raw);
      expect(t.name, 'Dark', reason: raw);
      expect((t.season, t.episode), (1, 2), reason: raw);
    }
  });

  test('a number inside the name is kept', () {
    final t = parseSeriesName('Brave 10 2012 S01E08');
    expect(t.name, 'Brave 10 2012');
    expect(t.episode, 8);
  });

  test('large episode numbers (soap operas)', () {
    final t = parseSeriesName('A História de Ana Raio e Zé Trovão S01E144');
    expect(t.episode, 144);
  });

  test('a name that does not match is never dropped', () {
    final t = parseSeriesName('  Documentário Especial  ');
    expect(t.name, 'Documentário Especial');
    expect((t.season, t.episode), (0, 0));
  });

  test('a name made only of the marker keeps the whole text', () {
    final t = parseSeriesName('S01E01');
    expect(t.name, 'S01E01');
  });
}
