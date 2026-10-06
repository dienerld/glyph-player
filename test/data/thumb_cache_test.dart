import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/thumb_cache.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('thumbs'));
  tearDown(() => tmp.delete(recursive: true));

  MockClient client(Map<String, int> hits, {int status = 200}) =>
      MockClient((req) async {
        hits.update(req.url.toString(), (n) => n + 1, ifAbsent: () => 1);
        return http.Response.bytes([1, 2, 3, 4], status);
      });

  test(
    'downloads once, then serves the saved file without the network',
    () async {
      final hits = <String, int>{};
      final cache = ThumbCache(tmp, client: client(hits));
      final a = await cache.get('http://x/p.jpg');
      expect(a!.readAsBytesSync(), [1, 2, 3, 4]);
      final b = await cache.get('http://x/p.jpg');
      expect(b!.path, a.path);
      expect(hits['http://x/p.jpg'], 1);
    },
  );

  test('a new cache instance reuses files saved by a previous run', () async {
    final hits = <String, int>{};
    await ThumbCache(tmp, client: client(hits)).get('http://x/p.jpg');
    final fresh = ThumbCache(tmp, client: client(hits));
    expect(await fresh.get('http://x/p.jpg'), isNotNull);
    expect(hits['http://x/p.jpg'], 1);
  });

  test('simultaneous requests for the same url share one download', () async {
    final hits = <String, int>{};
    final cache = ThumbCache(tmp, client: client(hits));
    final r = await Future.wait([
      for (var i = 0; i < 5; i++) cache.get('http://x/p.jpg'),
    ]);
    expect(r.every((f) => f != null), isTrue);
    expect(hits['http://x/p.jpg'], 1);
  });

  test(
    'a failed url returns null, leaves no file and is not retried this session',
    () async {
      final hits = <String, int>{};
      final cache = ThumbCache(tmp, client: client(hits, status: 404));
      expect(await cache.get('http://x/missing.jpg'), isNull);
      expect(await cache.get('http://x/missing.jpg'), isNull);
      expect(hits['http://x/missing.jpg'], 1);
      expect(tmp.listSync(), isEmpty);
    },
  );

  test('empty and malformed urls return null without a request', () async {
    final hits = <String, int>{};
    final cache = ThumbCache(tmp, client: client(hits));
    expect(await cache.get(''), isNull);
    expect(await cache.get('http://[bad'), isNull);
    expect(hits, isEmpty);
  });

  test('different urls get different files', () async {
    final cache = ThumbCache(tmp, client: client({}));
    final a = await cache.get('http://x/a.jpg');
    final b = await cache.get('http://x/b.jpg');
    expect(a!.path, isNot(b!.path));
  });

  test(
    'prune removes the least recently used files over the size cap',
    () async {
      final cache = ThumbCache(tmp, client: client({}));
      final names = ['a', 'b', 'c'];
      for (var i = 0; i < names.length; i++) {
        final f = File('${tmp.path}/${names[i]}')
          ..writeAsBytesSync(List.filled(100, 1));
        f.setLastModifiedSync(DateTime.utc(2026, 1, 1 + i));
      }
      await cache.prune(150);
      final left = tmp.listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(left, ['c']);
    },
  );

  test('prune leaves everything when under the cap', () async {
    final cache = ThumbCache(tmp, client: client({}));
    File('${tmp.path}/a').writeAsBytesSync(List.filled(100, 1));
    await cache.prune(1000);
    expect(tmp.listSync(), hasLength(1));
  });
}
