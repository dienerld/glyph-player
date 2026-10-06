import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late String path;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mig');
    path = '${tmp.path}/old.db';
    // Old schema (before series columns), with data to preserve.
    final old = sqlite3.open(path);
    old.execute('''
      CREATE TABLE streams(type TEXT NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL,
        grp TEXT NOT NULL, logo TEXT NOT NULL, url TEXT NOT NULL, run INTEGER NOT NULL,
        PRIMARY KEY(type, id));
      CREATE TABLE progress(type TEXT NOT NULL, id TEXT NOT NULL, position_ms INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY(type, id));
      INSERT INTO streams VALUES('series','1','Dark S01E02','Series | Netflix','','http://h/series/U/P/1.mp4',1);
      INSERT INTO streams VALUES('series','2','Sem Padrao','Novelas','','http://h/series/U/P/2.mp4',1);
      INSERT INTO streams VALUES('live','3','Globo','Globo','','http://h/live/U/P/3.ts',1);
      INSERT INTO progress VALUES('series','1',1000,5000,7);
    ''');
    old.close();
  });
  tearDown(() => tmp.delete(recursive: true));

  test('opening an old database fills series columns and keeps other data', () {
    final db = Db.open(path);
    final eps = db.episodes('Series | Netflix', 'Dark');
    expect(eps, hasLength(1));
    expect((eps[0].season, eps[0].episode), (1, 2));
    final loose = db.episodes('Novelas', 'Sem Padrao');
    expect((loose.single.season, loose.single.episode), (0, 0));
    expect(db.progressOf('series', '1')!.positionMs, 1000);
    expect(db.channels('live', 'Globo'), hasLength(1));
    db.close();
  });

  test('migration is idempotent', () {
    Db.open(path).close();
    final db = Db.open(path);
    expect(db.episodes('Series | Netflix', 'Dark'), hasLength(1));
    db.close();
  });
}
