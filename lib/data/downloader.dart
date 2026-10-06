import 'dart:io';
import 'package:http/http.dart' as http;

/// Streams [url] to `dest.path + '.part'` and renames onto [dest] only after a
/// complete, correctly sized download. Any failure leaves [dest] untouched.
Future<void> downloadTo(
  Uri url,
  File dest, {
  http.Client? client,
  Duration idleTimeout = const Duration(seconds: 30),
}) async {
  final c = client ?? http.Client();
  final part = File('${dest.path}.part');
  try {
    final res = await c
        .send(http.Request('GET', url))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    var received = 0;
    await res.stream
        .timeout(idleTimeout)
        .map((chunk) {
          received += chunk.length;
          return chunk;
        })
        .pipe(part.openWrite());
    final expected = res.contentLength;
    if (expected != null && received != expected) {
      throw HttpException(
        'Truncated download: $received of $expected bytes',
        uri: url,
      );
    }
    await part.rename(dest.path);
  } catch (_) {
    if (await part.exists()) await part.delete();
    rethrow;
  } finally {
    if (client == null) c.close();
  }
}
