import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Saves remote thumbnails to disk so each one is downloaded once, not every
/// time a card scrolls into view or the app restarts.
class ThumbCache {
  ThumbCache(this.dir, {http.Client? client, this.maxParallel = 6})
    : _client = client ?? http.Client();

  final Directory dir;
  final int maxParallel;
  final http.Client _client;

  final _known = <String, File>{};
  final _inFlight = <String, Future<File?>>{};
  final _failed = <String>{};
  final _waiters = Queue<Completer<void>>();
  var _active = 0;

  /// The saved file if it is already known in memory (no I/O), else null.
  File? peek(String url) => _known[url];

  /// The file for [url]: from disk if saved, otherwise downloaded and saved.
  /// Null when the url is empty/invalid or the download failed; a failed url is
  /// not retried during this session.
  Future<File?> get(String url) {
    if (url.isEmpty || _failed.contains(url)) return Future.value(null);
    final known = _known[url];
    if (known != null) return Future.value(known);
    return _inFlight.putIfAbsent(
      url,
      () => _load(url).whenComplete(() {
        // A block body: returning the Future from `remove` would make this
        // future wait on itself.
        _inFlight.remove(url);
      }),
    );
  }

  Future<File?> _load(String url) async {
    final file = File('${dir.path}/${_name(url)}');
    if (file.existsSync()) {
      try {
        file.setLastModifiedSync(DateTime.now()); // recently used
      } on FileSystemException {
        // Keeping the old timestamp only makes pruning slightly less accurate.
      }
      return _known[url] = file;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _failed.add(url);
      return null;
    }
    await _acquire();
    final part = File('${file.path}.part');
    try {
      await dir.create(recursive: true);
      final res = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        _failed.add(url);
        return null;
      }
      await part.writeAsBytes(res.bodyBytes, flush: true);
      await part.rename(file.path);
      return _known[url] = file;
    } catch (_) {
      _failed.add(url);
      if (part.existsSync()) part.deleteSync();
      return null;
    } finally {
      _release();
    }
  }

  /// Deletes the least recently used files until the cache fits [maxBytes].
  Future<void> prune(int maxBytes) async {
    if (!dir.existsSync()) return;
    final files = dir.listSync().whereType<File>().toList();
    var total = 0;
    final stats = <File, FileStat>{};
    for (final f in files) {
      final s = f.statSync();
      stats[f] = s;
      total += s.size;
    }
    files.sort((a, b) => stats[a]!.modified.compareTo(stats[b]!.modified));
    for (final f in files) {
      if (total <= maxBytes) break;
      total -= stats[f]!.size;
      f.deleteSync();
      _known.removeWhere((_, v) => v.path == f.path);
    }
  }

  Future<void> _acquire() async {
    if (_active < maxParallel) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future; // the slot is handed over, `_active` stays counted
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _active--;
    }
  }

  /// Stable file name per url (FNV-1a, two seeds → 64 bits as hex).
  static String _name(String url) {
    final bytes = utf8.encode(url);
    var a = 0x811c9dc5, b = 0x01000193 ^ 0x9747b28c;
    for (final x in bytes) {
      a = ((a ^ x) * 0x01000193) & 0xffffffff;
      b = ((b ^ x) * 0x01000193) & 0xffffffff;
    }
    return a.toRadixString(16).padLeft(8, '0') +
        b.toRadixString(16).padLeft(8, '0');
  }
}
