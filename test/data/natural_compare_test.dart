import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/natural_compare.dart';

void main() {
  test('digit runs compare as numbers, text ignores case', () {
    final names = ['100', '20', '10', '101', '11', 'canal 2', 'Canal 10'];
    names.sort(naturalCompare);
    expect(names, ['10', '11', '20', '100', '101', 'canal 2', 'Canal 10']);
  });
}
