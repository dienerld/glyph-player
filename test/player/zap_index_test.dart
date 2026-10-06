import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/player/player_page.dart';

void main() {
  test('zapIndex wraps in both directions', () {
    expect(zapIndex(0, 1, 3), 1);
    expect(zapIndex(2, 1, 3), 0);
    expect(zapIndex(0, -1, 3), 2);
  });
}
