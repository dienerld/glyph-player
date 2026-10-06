import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';

StreamEntry e(
  String id,
  String name,
  String group, {
  StreamType t = StreamType.live,
}) => StreamEntry(
  type: t,
  id: id,
  name: name,
  group: group,
  logo: '',
  url: 'http://h/${t.name}/U/P/$id.ts',
);

void main() {
  late Db db;
  setUp(() => db = Db.memory());
  tearDown(() => db.close());

  void load(List<StreamEntry> es) {
    final run = db.beginRun();
    db.upsertBatch(es, run);
    db.finishRun(run);
  }

  test('groups keep provider order and only include live', () {
    load([
      e('1', 'A', 'Globo'),
      e('2', 'B', 'Esportes'),
      e('3', 'C', 'Globo'),
      e('4', 'Movie', 'Filmes', t: StreamType.movie),
    ]);
    expect(db.liveGroups(), ['Globo', 'Esportes']);
    expect(db.liveChannels('Globo').map((c) => c.id), ['1', '3']);
  });

  test('second run updates rows and removes vanished ones', () {
    load([e('1', 'Old', 'G'), e('2', 'Gone', 'G')]);
    load([e('1', 'New', 'G')]);
    final ch = db.liveChannels('G');
    expect(ch.map((c) => c.name), ['New']);
  });

  test('FTS5 search is prefix, accent-insensitive and live-only', () {
    load([
      e('1', 'Programação Esportiva', 'G'),
      e('2', 'Filme Esporte', 'F', t: StreamType.movie),
    ]);
    expect(db.searchLive('programa').map((c) => c.id), ['1']);
    expect(db.searchLive('programacao').map((c) => c.id), ['1']);
  });

  test('search with FTS special characters does not throw', () {
    load([e('1', 'Globo', 'G')]);
    for (final q in ['"', '*', '-', '(', 'a:b', 'AND', '   ', '"glo"']) {
      expect(() => db.searchLive(q), returnsNormally, reason: q);
    }
    expect(db.searchLive('   '), isEmpty);
  });

  test(
    'favorites and recents survive a re-import and hide vanished streams',
    () {
      load([e('1', 'A', 'G'), e('2', 'B', 'G')]);
      db.setFavorite('live', '1', true);
      db.markWatched('live', '2', DateTime.utc(2026, 1, 1));
      db.markWatched('live', '1', DateTime.utc(2026, 1, 2));
      load([e('1', 'A', 'G')]);
      expect(db.favorites().map((c) => c.id), ['1']);
      expect(db.recents().map((c) => c.id), ['1']);
      db.setFavorite('live', '1', false);
      expect(db.isFavorite('live', '1'), isFalse);
    },
  );
}
