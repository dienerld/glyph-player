import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/natural_compare.dart';

void main() {
  test('digit runs compare as numbers, text ignores case', () {
    final names = ['100', '20', '10', '101', '11', 'canal 2', 'Canal 10'];
    names.sort(naturalCompare);
    expect(names, ['10', '11', '20', '100', '101', 'canal 2', 'Canal 10']);
  });

  test('variants stay with their channel, in quality order', () {
    final names = [
      'ESPN 2 HD',
      'ESPN FHD',
      'ESPN 10',
      'ESPN H265',
      'ESPN 2',
      'ESPN [4K]',
      'ESPN FHD H265',
      'ESPN HD',
      'ESPN SD',
      'ESPN',
      'ESPN 2 FHD',
    ];
    names.sort(channelCompare);
    expect(names, [
      'ESPN',
      'ESPN SD',
      'ESPN HD',
      'ESPN FHD',
      'ESPN FHD H265',
      'ESPN [4K]',
      'ESPN H265',
      'ESPN 2',
      'ESPN 2 HD',
      'ESPN 2 FHD',
      'ESPN 10',
    ]);
  });

  test('other trailing tags group with the channel and come last', () {
    final names = ['HBO Plus HD', 'HBO FHD [L]', 'HBO HD', 'HBO', 'HBO FHD'];
    names.sort(channelCompare);
    expect(names, ['HBO', 'HBO HD', 'HBO FHD', 'HBO FHD [L]', 'HBO Plus HD']);
  });

  test('a tag word inside the name is part of the name', () {
    final names = ['HD Channel', 'Canal HD Plus', 'Canal'];
    names.sort(channelCompare);
    expect(names, ['Canal', 'Canal HD Plus', 'HD Channel']);
  });
}
