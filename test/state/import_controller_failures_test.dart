import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/playlist_url_store.dart';
import 'package:glyph_player/state/providers.dart';

class _Store implements PlaylistUrlStore {
  _Store({this.url, this.failRead = false, this.failWrite = false});
  String? url;
  final bool failRead, failWrite;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('libsecret missing');
    return url;
  }

  @override
  Future<void> write(String u) async {
    if (failWrite) throw StateError('libsecret missing');
    url = u;
  }
}

Future<(ProviderContainer, Future<void> Function())> setup(PlaylistUrlStore store) async {
  final tmp = await Directory.systemTemp.createTemp('ctlf');
  final paths = AppPaths(
    dbPath: '${tmp.path}/g.db',
    downloadPath: '${tmp.path}/p.m3u',
  );
  final db = Db.open(paths.dbPath);
  final c = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      appPathsProvider.overrideWithValue(paths),
      playlistUrlStoreProvider.overrideWithValue(store),
    ],
  );
  return (
    c,
    () async {
      c.dispose();
      db.close();
      await tmp.delete(recursive: true);
    },
  );
}

void main() {
  test('failure message never exposes the playlist credentials', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) {
      r.response.statusCode = 404;
      r.response.close();
    });
    final (c, done) = await setup(
      _Store(
        url:
            'http://127.0.0.1:${server.port}/get.php?username=U&password=SECRETPW',
      ),
    );
    addTearDown(() async {
      await done();
      await server.close(force: true);
    });
    await c.read(importControllerProvider.notifier).refresh();
    final s = c.read(importControllerProvider);
    expect(s, isA<ImportFailed>());
    final msg = (s as ImportFailed).message;
    expect(msg, isNot(contains('SECRETPW')));
    expect(msg, isNot(contains('password')));
  });

  test('secure store read failure becomes a visible ImportFailed', () async {
    final (c, done) = await setup(_Store(failRead: true));
    addTearDown(done);
    await c.read(importControllerProvider.notifier).refresh();
    expect(c.read(importControllerProvider), isA<ImportFailed>());
  });

  test('secure store write failure becomes a visible ImportFailed', () async {
    final (c, done) = await setup(_Store(failWrite: true));
    addTearDown(done);
    await c
        .read(importControllerProvider.notifier)
        .refresh(newUrl: 'http://x/get.php');
    expect(c.read(importControllerProvider), isA<ImportFailed>());
  });

  test('two simultaneous refreshes run a single import', () async {
    var hits = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) {
      hits++;
      r.response.write(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="" tvg-name="A" tvg-logo="" group-title="G",A\n'
        'http://h/live/U/P/1.ts\n',
      );
      r.response.close();
    });
    final (c, done) = await setup(
      _Store(url: 'http://127.0.0.1:${server.port}/get.php'),
    );
    addTearDown(() async {
      await done();
      await server.close(force: true);
    });
    final n = c.read(importControllerProvider.notifier);
    await Future.wait([n.refresh(), n.refresh()]);
    expect(hits, 1);
  });
}
