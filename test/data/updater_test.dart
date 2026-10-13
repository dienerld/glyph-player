import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/updater.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client release(Map<String, dynamic> json, {int status = 200}) =>
    MockClient((_) async => http.Response(jsonEncode(json), status));

final latest = {
  'tag_name': 'v0.4.0',
  'body': 'Notas',
  'html_url': 'https://github.com/dienerld/glyph-player/releases/tag/v0.4.0',
  'assets': [
    {
      'name': 'glyph-player-0.4.0-windows-x64.zip',
      'browser_download_url': 'https://x/win.zip',
    },
    {
      'name': 'glyph-player-0.4.0-linux-x64.tar.gz',
      'browser_download_url': 'https://x/linux.tar.gz',
    },
  ],
};

void main() {
  test('isNewer compares numerically, not as text', () {
    expect(isNewer('0.10.0', '0.9.0'), isTrue);
    expect(isNewer('0.3.1', '0.3.0'), isTrue);
    expect(isNewer('0.3.0', '0.3.0'), isFalse);
    expect(isNewer('0.2.9', '0.3.0'), isFalse);
  });

  test('a newer release is reported with its platform asset', () async {
    final u = await fetchUpdate(
      '0.3.0',
      client: release(latest),
      assetSuffix: '-linux-x64.tar.gz',
    );
    expect(u!.version, '0.4.0');
    expect(u.notes, 'Notas');
    expect(u.assetUrl.toString(), 'https://x/linux.tar.gz');
  });

  test('no matching asset still reports the update (page fallback)', () async {
    final u = await fetchUpdate(
      '0.3.0',
      client: release(latest),
      assetSuffix: '-setup.exe',
    );
    expect(u!.assetUrl, isNull);
    expect(u.pageUrl, contains('/releases/tag/v0.4.0'));
  });

  test('up to date returns null', () async {
    expect(await fetchUpdate('0.4.0', client: release(latest)), isNull);
  });

  test('an HTTP error throws', () async {
    expect(
      fetchUpdate('0.3.0', client: release({}, status: 403)),
      throwsA(isA<Exception>()),
    );
  });
}
