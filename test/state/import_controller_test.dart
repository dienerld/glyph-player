import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/playlist_url_store.dart';
import 'package:glyph_player/state/providers.dart';

class _FakeStore implements PlaylistUrlStore {
  _FakeStore(this.url);
  String? url;
  @override
  Future<String?> read() async => url;
  @override
  Future<void> write(String u) async => url = u;
}

void main() {
  test('refresh downloads, imports, cleans up and exposes groups', () async {
    final tmp = await Directory.systemTemp.createTemp('ctl');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) {
      r.response.write(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="" tvg-name="A" tvg-logo="" group-title="Canais | Globo",A\n'
        'http://h/live/U/P/1.ts\n',
      );
      r.response.close();
    });
    final paths = AppPaths(
      dbPath: '${tmp.path}/g.db',
      downloadPath: '${tmp.path}/p.m3u',
    );
    final db = Db.open(paths.dbPath);
    final c = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        appPathsProvider.overrideWithValue(paths),
        playlistUrlStoreProvider.overrideWithValue(
          _FakeStore('http://127.0.0.1:${server.port}/get.php'),
        ),
      ],
    );
    addTearDown(() async {
      c.dispose();
      db.close();
      await server.close(force: true);
      await tmp.delete(recursive: true);
    });

    await c.read(importControllerProvider.notifier).refresh();

    expect(c.read(importControllerProvider), isA<ImportIdle>());
    expect((await c.read(liveGroupsProvider.future)).map((g) => g.name), [
      'Globo',
    ]);
    expect(File(paths.downloadPath).existsSync(), isFalse);
  });

  test('refresh without a configured URL reports a failure', () async {
    final tmp = await Directory.systemTemp.createTemp('ctl');
    final paths = AppPaths(
      dbPath: '${tmp.path}/g.db',
      downloadPath: '${tmp.path}/p.m3u',
    );
    final db = Db.open(paths.dbPath);
    final c = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        appPathsProvider.overrideWithValue(paths),
        playlistUrlStoreProvider.overrideWithValue(_FakeStore(null)),
      ],
    );
    addTearDown(() async {
      c.dispose();
      db.close();
      await tmp.delete(recursive: true);
    });
    await c.read(importControllerProvider.notifier).refresh();
    expect(c.read(importControllerProvider), isA<ImportFailed>());
  });
}
