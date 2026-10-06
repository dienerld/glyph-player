import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/state/providers.dart';

StreamEntry ep(String id, String group, String series) => StreamEntry(
  type: StreamType.series,
  id: id,
  name: '$series S1E1',
  group: group,
  logo: '',
  url: 'http://h/series/U/P/$id.mp4',
  seriesName: series,
  season: 1,
  episode: 1,
);

void main() {
  test(
    'adult series sections are hidden by default and shown on opt-in',
    () async {
      final db = Db.memory();
      final run = db.beginRun();
      db.upsertBatch([
        ep('1', 'Series | Netflix', 'Dark'),
        ep('2', 'Hentai [adultos]', 'X'),
      ], run);
      db.finishRun(run);
      final c = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(() {
        c.dispose();
        db.close();
      });
      expect((await c.read(seriesSectionsProvider.future)).map((g) => g.name), [
        'Series | Netflix',
      ]);
      c.read(showAdultProvider.notifier).set(true);
      expect((await c.read(seriesSectionsProvider.future)).length, 2);
    },
  );

  test('continue and favorites providers read the db', () async {
    final db = Db.memory();
    final run = db.beginRun();
    db.upsertBatch([ep('1', 'Series | Netflix', 'Dark')], run);
    db.finishRun(run);
    db.touchProgress('series', '1', DateTime.utc(2026, 1, 1));
    db.setSeriesFavorite('Series | Netflix', 'Dark', true);
    final c = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    addTearDown(() {
      c.dispose();
      db.close();
    });
    expect((await c.read(continueSeriesProvider.future)).single.name, 'Dark');
    expect((await c.read(seriesFavoritesProvider.future)).single.name, 'Dark');
    expect(
      (await c.read(
        seriesEpisodesProvider(('Series | Netflix', 'Dark')).future,
      )).length,
      1,
    );
  });
}
