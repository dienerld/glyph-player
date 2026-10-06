import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/downloader.dart';

void main() {
  late Directory tmp;
  late HttpServer server;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dl');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });
  Uri url() => Uri.parse('http://127.0.0.1:${server.port}/get.php');

  test('downloads body to dest', () async {
    server.listen((r) {
      r.response.write('#EXTM3U\n');
      r.response.close();
    });
    final dest = File('${tmp.path}/p.m3u');
    await downloadTo(url(), dest);
    expect(await dest.readAsString(), '#EXTM3U\n');
    expect(File('${dest.path}.part').existsSync(), isFalse);
  });

  test('HTTP error throws and leaves existing file intact', () async {
    server.listen((r) {
      r.response.statusCode = 500;
      r.response.close();
    });
    final dest = File('${tmp.path}/p.m3u')..writeAsStringSync('old');
    await expectLater(downloadTo(url(), dest), throwsA(isA<HttpException>()));
    expect(dest.readAsStringSync(), 'old');
    expect(File('${dest.path}.part').existsSync(), isFalse);
  });

  test('truncated body throws and leaves existing file intact', () async {
    final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(raw.close);
    raw.listen((s) async {
      s.add('HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\nshort'.codeUnits);
      await s.flush();
      s.destroy();
    });
    final dest = File('${tmp.path}/p.m3u')..writeAsStringSync('old');
    await expectLater(
      downloadTo(Uri.parse('http://127.0.0.1:${raw.port}/get.php'), dest),
      throwsA(anything),
    );
    expect(dest.readAsStringSync(), 'old');
    expect(File('${dest.path}.part').existsSync(), isFalse);
  });
}
