import 'package:sqlite3/sqlite3.dart';

import 'stream_entry.dart';

class Channel {
  const Channel({
    required this.type,
    required this.id,
    required this.name,
    required this.group,
    required this.logo,
    required this.url,
  });

  final String type, id, name, group, logo, url;
}

const _schema = '''
CREATE TABLE IF NOT EXISTS streams(
  type TEXT NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL, grp TEXT NOT NULL,
  logo TEXT NOT NULL, url TEXT NOT NULL, run INTEGER NOT NULL,
  PRIMARY KEY(type, id));
CREATE INDEX IF NOT EXISTS streams_type_grp ON streams(type, grp);
CREATE VIRTUAL TABLE IF NOT EXISTS streams_fts USING fts5(
  name, content='streams', content_rowid='rowid',
  tokenize='unicode61 remove_diacritics 2');
CREATE TABLE IF NOT EXISTS favorites(
  type TEXT NOT NULL, id TEXT NOT NULL, PRIMARY KEY(type, id));
CREATE TABLE IF NOT EXISTS recents(
  type TEXT NOT NULL, id TEXT NOT NULL, watched_at INTEGER NOT NULL,
  PRIMARY KEY(type, id));
''';

const _cols = 's.type, s.id, s.name, s.grp, s.logo, s.url';

class Db {
  Db._(this._db) {
    _db.execute(
      'PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; PRAGMA synchronous=NORMAL;',
    );
    _db.execute(_schema);
  }

  factory Db.open(String path) => Db._(sqlite3.open(path));
  factory Db.memory() => Db._(sqlite3.openInMemory());

  final Database _db;

  void close() => _db.close();

  int streamCount() =>
      _db.select('SELECT COUNT(*) AS n FROM streams').first['n'] as int;

  int beginRun() =>
      (_db
              .select('SELECT COALESCE(MAX(run), 0) + 1 AS r FROM streams')
              .first['r']
          as int);

  void upsertBatch(List<StreamEntry> entries, int run) {
    final stmt = _db.prepare(
      'INSERT INTO streams(type,id,name,grp,logo,url,run) VALUES(?,?,?,?,?,?,?) '
      'ON CONFLICT(type,id) DO UPDATE SET name=excluded.name, grp=excluded.grp, '
      'logo=excluded.logo, url=excluded.url, run=excluded.run',
    );
    _db.execute('BEGIN');
    try {
      for (final e in entries) {
        stmt.execute([e.type.name, e.id, e.name, e.group, e.logo, e.url, run]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      stmt.close();
    }
  }

  /// Drops rows not seen in [run] and rebuilds the search index. Call only
  /// after a fully successful import.
  void finishRun(int run) {
    _db.execute('DELETE FROM streams WHERE run <> ?', [run]);
    _db.execute("INSERT INTO streams_fts(streams_fts) VALUES('rebuild')");
  }

  List<String> liveGroups() => _db
      .select(
        "SELECT grp FROM streams WHERE type='live' GROUP BY grp ORDER BY MIN(rowid)",
      )
      .map((r) => r['grp'] as String)
      .toList();

  List<Channel> liveChannels(String group) => _channels(
    "SELECT $_cols FROM streams s WHERE s.type='live' AND s.grp=? ORDER BY s.rowid",
    [group],
  );

  List<Channel> searchLive(String text, {int limit = 60}) {
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*')
        .join(' ');
    if (tokens.isEmpty) return const [];
    return _channels(
      "SELECT $_cols FROM streams_fts f JOIN streams s ON s.rowid = f.rowid "
      "WHERE streams_fts MATCH ? AND s.type='live' ORDER BY f.rank LIMIT ?",
      [tokens, limit],
    );
  }

  List<Channel> favorites() => _channels(
    "SELECT $_cols FROM favorites f JOIN streams s ON s.type=f.type AND s.id=f.id "
    "WHERE s.type='live' ORDER BY s.name",
    const [],
  );

  List<Channel> recents({int limit = 20}) => _channels(
    "SELECT $_cols FROM recents r JOIN streams s ON s.type=r.type AND s.id=r.id "
    "WHERE s.type='live' ORDER BY r.watched_at DESC LIMIT ?",
    [limit],
  );

  bool isFavorite(String type, String id) => _db.select(
    'SELECT 1 FROM favorites WHERE type=? AND id=?',
    [type, id],
  ).isNotEmpty;

  void setFavorite(String type, String id, bool value) {
    if (value) {
      _db.execute('INSERT OR IGNORE INTO favorites(type,id) VALUES(?,?)', [
        type,
        id,
      ]);
    } else {
      _db.execute('DELETE FROM favorites WHERE type=? AND id=?', [type, id]);
    }
  }

  void markWatched(String type, String id, DateTime at) => _db.execute(
    'INSERT INTO recents(type,id,watched_at) VALUES(?,?,?) '
    'ON CONFLICT(type,id) DO UPDATE SET watched_at=excluded.watched_at',
    [type, id, at.millisecondsSinceEpoch],
  );

  List<Channel> _channels(String sql, List<Object?> args) => _db
      .select(sql, args)
      .map(
        (r) => Channel(
          type: r['type'] as String,
          id: r['id'] as String,
          name: r['name'] as String,
          group: r['grp'] as String,
          logo: r['logo'] as String,
          url: r['url'] as String,
        ),
      )
      .toList();
}
