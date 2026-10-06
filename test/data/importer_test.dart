import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/importer.dart';

String entry(String id, String name) =>
    '#EXTINF:-1 tvg-id="" tvg-name="$name" tvg-logo="" group-title="Canais | G",$name\r\n'
    'http://h/live/U/P/$id.ts\r\n';

void main() {
  late Directory tmp;
  late String dbPath;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('imp');
    dbPath = '${tmp.path}/t.db';
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<File> list(String body) async =>
      File('${tmp.path}/l.m3u')..writeAsStringSync(body);

  test('imports entries and reports progress', () async {
    final f = await list('#EXTM3U\r\n${entry('1', 'A')}${entry('2', 'B')}');
    final n = await importInBackground(dbPath, f, (_) {});
    expect(n, 2);
    final db = Db.open(dbPath);
    expect(db.liveChannels('G'), hasLength(2));
    db.close();
  });

  test('malformed UTF-8 bytes do not abort the import', () async {
    final f = File('${tmp.path}/l.m3u');
    f.writeAsBytesSync([
      ...'#EXTM3U\n'.codeUnits,
      ...'#EXTINF:-1 tvg-id="" tvg-name="Bad" tvg-logo="" group-title="G",Bad '.codeUnits,
      0xFF, 0xFE,
      ...'\nhttp://h/live/U/P/1.ts\n'.codeUnits,
    ]);
    expect(await importFile(dbPath: dbPath, file: f), 1);
  });

  test('empty list throws and does not wipe existing data', () async {
    await importFile(dbPath: dbPath, file: await list('#EXTM3U\n${entry('1', 'A')}'));
    final empty = await list('');
    await expectLater(importFile(dbPath: dbPath, file: empty), throwsFormatException);
    final db = Db.open(dbPath);
    expect(db.liveChannels('G'), hasLength(1));
    db.close();
  });
}
