import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'database.dart';
import 'm3u_parser.dart';
import 'stream_entry.dart';

const _batchSize = 5000;

/// Parses [file] and upserts it into the DB at [dbPath]. Old rows are removed
/// only after the whole file parsed with at least one entry.
Future<int> importFile({
  required String dbPath,
  required File file,
  void Function(int count)? onProgress,
}) async {
  final db = Db.open(dbPath);
  try {
    final run = db.beginRun();
    final batch = <StreamEntry>[];
    var count = 0;
    final lines = file
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    await for (final e in parseM3u(lines)) {
      batch.add(e);
      count++;
      if (batch.length >= _batchSize) {
        db.upsertBatch(batch, run);
        batch.clear();
        onProgress?.call(count);
      }
    }
    if (count == 0) throw const FormatException('Playlist has no entries');
    db.upsertBatch(batch, run);
    db.finishRun(run);
    onProgress?.call(count);
    return count;
  } finally {
    db.close();
  }
}

/// Runs [importFile] in a separate isolate; [onProgress] runs on the caller.
Future<int> importInBackground(String dbPath, File file, void Function(int) onProgress) async {
  final port = ReceivePort();
  final sub = port.listen((m) => onProgress(m as int));
  try {
    return await _runIsolate(dbPath, file, port.sendPort);
  } finally {
    await sub.cancel();
    port.close();
  }
}

// Separate scope so the isolate closure captures only sendable values.
Future<int> _runIsolate(String dbPath, File file, SendPort send) =>
    Isolate.run(() => importFile(dbPath: dbPath, file: file, onProgress: send.send));
