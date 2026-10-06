import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';

StreamEntry ep(
  String id,
  String group,
  String series,
  int s,
  int e, {
  String logo = '',
}) => StreamEntry(
  type: StreamType.series,
  id: id,
  name: '$series S${s}E$e',
  group: group,
  logo: logo,
  url: 'http://h/series/U/P/$id.mp4',
  seriesName: series,
  season: s,
  episode: e,
);

void main() {
  late Db db;
  setUp(() {
    db = Db.memory();
    final run = db.beginRun();
    db.upsertBatch([
      ep('1', 'Series | Netflix', 'Dark', 1, 1, logo: 'http://p/dark.jpg'),
      ep('2', 'Series | Netflix', 'Dark', 1, 2),
      ep('3', 'Series | Netflix', 'Dark', 2, 1),
      ep('4', 'Series | Netflix', 'Alias', 1, 1),
      ep('5', 'Novelas', 'A Gata', 1, 1),
      ep('6', 'Series | Netflix', 'Dark', 1, 2), // duplicate (season, episode)
    ], run);
    db.finishRun(run);
  });
  tearDown(() => db.close());

  test('seriesIn summarises name, poster, seasons and episodes, sorted by name', () {
    final list = db.seriesIn('Series | Netflix');
    expect(list.map((s) => s.name), ['Alias', 'Dark']);
    final dark = list[1];
    expect(dark.poster, 'http://p/dark.jpg');
    expect(dark.seasons, 2);
    expect(dark.episodes, 4);
  });

  test('episodes keep duplicates, ordered by season then episode', () {
    final e = db.episodes('Series | Netflix', 'Dark');
    expect(e.map((x) => x.item.id), ['1', '2', '6', '3']);
  });

  test('series favorites toggle and list', () {
    expect(db.isSeriesFavorite('Series | Netflix', 'Dark'), isFalse);
    db.setSeriesFavorite('Series | Netflix', 'Dark', true);
    expect(db.isSeriesFavorite('Series | Netflix', 'Dark'), isTrue);
    expect(db.seriesFavorites().map((s) => s.name), ['Dark']);
    db.setSeriesFavorite('Series | Netflix', 'Dark', false);
    expect(db.seriesFavorites(), isEmpty);
  });

  test('continueSeries: one entry per series, most recent first', () {
    db.touchProgress('series', '4', DateTime.utc(2026, 1, 1));
    db.saveProgress('series', '2', 1000, 5000, DateTime.utc(2026, 1, 3));
    db.saveProgress('series', '1', 1000, 5000, DateTime.utc(2026, 1, 2));
    expect(db.continueSeries().map((s) => s.name), ['Dark', 'Alias']);
  });

  test('hidden series leaves Continue and returns only after new watching', () {
    db.saveProgress('series', '2', 1000, 5000, DateTime.utc(2026, 1, 3));
    db.hideSeries('Series | Netflix', 'Dark', DateTime.utc(2026, 1, 4));
    expect(db.continueSeries(), isEmpty);
    expect(db.progressOf('series', '2'), isNotNull); // progress kept
    db.touchProgress('series', '3', DateTime.utc(2026, 1, 5));
    expect(db.continueSeries().map((s) => s.name), ['Dark']);
  });

  test('touchProgress keeps an existing resume position', () {
    db.saveProgress('series', '2', 4000, 5000, DateTime.utc(2026, 1, 1));
    db.touchProgress('series', '2', DateTime.utc(2026, 1, 9));
    expect(db.progressOf('series', '2')!.positionMs, 4000);
  });

  test('seriesCount counts distinct series in a group', () {
    expect(db.seriesCount('Series | Netflix'), 2);
    expect(db.seriesCount('Novelas'), 1);
    expect(db.seriesCount('Inexistente'), 0);
  });

  test('lastWatched returns the most recent episode with its progress', () {
    db.saveProgress('series', '1', 1000, 5000, DateTime.utc(2026, 1, 1));
    db.saveProgress('series', '3', 2000, 5000, DateTime.utc(2026, 1, 2));
    final (item, p) = db.lastWatched('Series | Netflix', 'Dark')!;
    expect(item.id, '3');
    expect(p.positionMs, 2000);
    expect(db.lastWatched('Series | Netflix', 'Alias'), isNull);
  });
}
