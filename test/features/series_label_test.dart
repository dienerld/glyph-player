import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/features/series/series_card.dart';

void main() {
  test('distributor label drops the Series prefix and keeps collections', () {
    expect(distributorLabel('Series | Netflix'), 'Netflix');
    expect(distributorLabel('Novelas'), 'Novelas');
  });

  test('a group with no name is labelled instead of rendering blank', () {
    expect(distributorLabel(''), 'Sem categoria');
    expect(distributorLabel('   '), 'Sem categoria');
  });
}
