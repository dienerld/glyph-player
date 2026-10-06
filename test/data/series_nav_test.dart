import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/series_nav.dart';

Episode e(String id, int s, int n) => Episode(
  Channel(
    type: 'series',
    id: id,
    name: 'X S${s}E$n',
    group: 'g',
    logo: '',
    url: 'u$id',
  ),
  s,
  n,
);

void main() {
  final eps = [
    e('1', 1, 1),
    e('2', 1, 2),
    e('3', 1, 2),
    e('4', 2, 1),
  ]; // '3' duplicates '2'

  test('next skips a duplicate of the current episode', () {
    expect(nextIndex(eps, 1), 3);
  });

  test('next crosses into the next season', () {
    expect(nextIndex([e('1', 1, 9), e('2', 2, 1)], 0), 1);
  });

  test('next is null on the last episode', () {
    expect(nextIndex(eps, 3), isNull);
  });

  test('continue stays on an unfinished episode', () {
    expect(continueIndex(eps, 1, const Progress(60000, 600000)), 1);
  });

  test('continue moves to the next episode once the last one is finished', () {
    expect(continueIndex(eps, 0, const Progress(590000, 600000)), 1);
  });

  test('continue on a finished last episode reopens it', () {
    expect(continueIndex(eps, 3, const Progress(590000, 600000)), 3);
  });
}
