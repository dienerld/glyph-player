import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/state/providers.dart';

StreamEntry e(String id, String name, String group, StreamType t) => StreamEntry(
      type: t,
      id: id,
      name: name,
      group: group,
      logo: '',
      url: 'http://h/${t.name}/U/P/$id.ts',
    );

void main() {
  late Db db;
  late ProviderContainer c;
  setUp(() {
    db = Db.memory();
    final run = db.beginRun();
    db.upsertBatch([
      e('1', 'Globo', 'Globo', StreamType.live),
      e('2', 'Canal X', 'Adultos', StreamType.live),
      e('3', 'Palmer (2021)', 'Filmes | Drama', StreamType.movie),
      e('4', 'Palmer Adulto', 'Filmes Adultos', StreamType.movie),
    ], run);
    db.finishRun(run);
    c = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
  });
  tearDown(() {
    c.dispose();
    db.close();
  });

  test('adult content is hidden by default in groups and search', () async {
    expect(c.read(showAdultProvider), isFalse);
    expect(await c.read(liveGroupsProvider.future), ['Globo']);
    expect((await c.read(movieGroupsProvider.future)).map((g) => g.name), ['Filmes | Drama']);
    final r = await c.read(searchProvider(('movie', 'palmer')).future);
    expect(r.map((x) => x.id), ['3']);
  });

  test('turning the option on shows adult groups and persists it', () async {
    c.read(showAdultProvider.notifier).set(true);
    expect(await c.read(liveGroupsProvider.future), ['Globo', 'Adultos']);
    expect((await c.read(movieGroupsProvider.future)).length, 2);
    expect(db.setting('show_adult'), '1');
    final c2 = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    addTearDown(c2.dispose);
    expect(c2.read(showAdultProvider), isTrue);
  });
}
