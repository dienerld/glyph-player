// Proxy for "UI never freezes": the main isolate's event loop must keep ticking
// while the importer runs. Needs the real list: GLYPH_REAL_LIST=/path/list.m3u
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/importer.dart';

void main() {
  final path = Platform.environment['GLYPH_REAL_LIST'];
  test('event loop stays responsive during a real import', () async {
    final tmp = await Directory.systemTemp.createTemp('resp');
    var last = Stopwatch()..start();
    var maxGapMs = 0;
    final timer = Stream.periodic(const Duration(milliseconds: 10)).listen((_) {
      final gap = last.elapsedMilliseconds;
      if (gap > maxGapMs) maxGapMs = gap;
      last = Stopwatch()..start();
    });
    final sw = Stopwatch()..start();
    final n = await importInBackground('${tmp.path}/r.db', File(path!), (_) {});
    await timer.cancel();
    // ignore: avoid_print
    print('imported $n entries in ${sw.elapsed}, max event-loop gap ${maxGapMs}ms');
    expect(maxGapMs, lessThan(100));
    await tmp.delete(recursive: true);
  }, skip: path == null ? 'set GLYPH_REAL_LIST' : false, timeout: const Timeout(Duration(minutes: 5)));
}
