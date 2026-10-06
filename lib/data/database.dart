import 'package:sqlite3/sqlite3.dart';

import 'series_title.dart';
import 'stream_entry.dart';

class GroupCount {
  const GroupCount(this.name, this.count);
  final String name;
  final int count;
}

class Progress {
  const Progress(this.positionMs, this.durationMs);
  final int positionMs, durationMs;
}

class Episode {
  const Episode(this.item, this.season, this.episode);
  final Channel item;
  final int season, episode;
}

class SeriesSummary {
  const SeriesSummary(
    this.group,
    this.name,
    this.poster,
    this.seasons,
    this.episodes,
  );
  final String group, name, poster;
  final int seasons, episodes;
}

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
  series_name TEXT NOT NULL DEFAULT '', season INTEGER NOT NULL DEFAULT 0,
  episode INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(type, id));
CREATE INDEX IF NOT EXISTS streams_type_grp ON streams(type, grp);
CREATE VIRTUAL TABLE IF NOT EXISTS streams_fts USING fts5(
  name, content='streams', content_rowid='rowid',
  tokenize='unicode61 remove_diacritics 2');
CREATE TABLE IF NOT EXISTS favorites(
  type TEXT NOT NULL, id TEXT NOT NULL, PRIMARY KEY(type, id));
CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS progress(
  type TEXT NOT NULL, id TEXT NOT NULL, position_ms INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  PRIMARY KEY(type, id));
CREATE TABLE IF NOT EXISTS series_favorites(
  grp TEXT NOT NULL, series_name TEXT NOT NULL, PRIMARY KEY(grp, series_name));
CREATE TABLE IF NOT EXISTS series_hidden(
  grp TEXT NOT NULL, series_name TEXT NOT NULL, hidden_at INTEGER NOT NULL,
  PRIMARY KEY(grp, series_name));
CREATE TABLE IF NOT EXISTS recents(
  type TEXT NOT NULL, id TEXT NOT NULL, watched_at INTEGER NOT NULL,
  PRIMARY KEY(type, id));
''';

const _summaryCols =
    's.grp, s.series_name, MAX(s.logo) AS poster, '
    'COUNT(DISTINCT s.season) AS seasons, COUNT(*) AS episodes';

const _cols = 's.type, s.id, s.name, s.grp, s.logo, s.url';

class Db {
  Db._(this._db) {
    _db.execute(
      'PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; PRAGMA synchronous=NORMAL;',
    );
    _db.execute(_schema);
    _migrate();
  }

  factory Db.open(String path) => Db._(sqlite3.open(path));
  factory Db.memory() => Db._(sqlite3.openInMemory());

  final Database _db;

  void close() => _db.close();

  /// Adds the series columns to databases created before them and fills them
  /// from the stored names. Idempotent.
  void _migrate() {
    final cols = _db
        .select('PRAGMA table_info(streams)')
        .map((r) => r['name'] as String)
        .toSet();
    if (!cols.contains('series_name')) {
      _db.execute('BEGIN');
      try {
        _db.execute(
          "ALTER TABLE streams ADD COLUMN series_name TEXT NOT NULL DEFAULT ''",
        );
        _db.execute(
          'ALTER TABLE streams ADD COLUMN season INTEGER NOT NULL DEFAULT 0',
        );
        _db.execute(
          'ALTER TABLE streams ADD COLUMN episode INTEGER NOT NULL DEFAULT 0',
        );
        final upd = _db.prepare(
          'UPDATE streams SET series_name=?, season=?, episode=? '
          'WHERE type=? AND id=?',
        );
        try {
          final rows = _db.select(
            "SELECT id, name FROM streams WHERE type='series'",
          );
          for (final r in rows) {
            final t = parseSeriesName(r['name'] as String);
            upd.execute([t.name, t.season, t.episode, 'series', r['id']]);
          }
        } finally {
          upd.close();
        }
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      }
    }
    _db.execute(
      'CREATE INDEX IF NOT EXISTS streams_series ON streams(type, grp, series_name)',
    );
    _db.execute('PRAGMA user_version = 1');
  }

  int streamCount() =>
      _db.select('SELECT COUNT(*) AS n FROM streams').first['n'] as int;

  int beginRun() =>
      (_db
              .select('SELECT COALESCE(MAX(run), 0) + 1 AS r FROM streams')
              .first['r']
          as int);

  void upsertBatch(List<StreamEntry> entries, int run) {
    final stmt = _db.prepare(
      'INSERT INTO streams(type,id,name,grp,logo,url,run,series_name,season,episode) '
      'VALUES(?,?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(type,id) DO UPDATE SET name=excluded.name, grp=excluded.grp, '
      'logo=excluded.logo, url=excluded.url, run=excluded.run, '
      'series_name=excluded.series_name, season=excluded.season, '
      'episode=excluded.episode',
    );
    _db.execute('BEGIN');
    try {
      for (final e in entries) {
        stmt.execute([
          e.type.name,
          e.id,
          e.name,
          e.group,
          e.logo,
          e.url,
          run,
          e.seriesName,
          e.season,
          e.episode,
        ]);
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

  List<GroupCount> groups(String type) => _db
      .select(
        'SELECT grp, COUNT(*) AS n FROM streams WHERE type=? GROUP BY grp ORDER BY MIN(rowid)',
        [type],
      )
      .map((r) => GroupCount(r['grp'] as String, r['n'] as int))
      .toList();

  List<Channel> channels(String type, String group) => _channels(
    "SELECT $_cols FROM streams s WHERE s.type=? AND s.grp=? ORDER BY s.rowid",
    [type, group],
  );

  List<Channel> search(String type, String text, {int limit = 60}) {
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*')
        .join(' ');
    if (tokens.isEmpty) return const [];
    return _channels(
      "SELECT $_cols FROM streams_fts f JOIN streams s ON s.rowid = f.rowid "
      "WHERE streams_fts MATCH ? AND s.type=? ORDER BY f.rank LIMIT ?",
      [tokens, type, limit],
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

  String? setting(String key) {
    final r = _db.select('SELECT value FROM settings WHERE key=?', [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  void setSetting(String key, String value) => _db.execute(
    'INSERT INTO settings(key,value) VALUES(?,?) '
    'ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, value],
  );

  void saveProgress(
    String type,
    String id,
    int positionMs,
    int durationMs,
    DateTime at,
  ) => _db.execute(
    'INSERT INTO progress(type,id,position_ms,duration_ms,updated_at) VALUES(?,?,?,?,?) '
    'ON CONFLICT(type,id) DO UPDATE SET position_ms=excluded.position_ms, '
    'duration_ms=excluded.duration_ms, updated_at=excluded.updated_at',
    [type, id, positionMs, durationMs, at.millisecondsSinceEpoch],
  );

  Progress? progressOf(String type, String id) {
    final r = _db.select(
      'SELECT position_ms, duration_ms FROM progress WHERE type=? AND id=?',
      [type, id],
    );
    if (r.isEmpty) return null;
    return Progress(
      r.first['position_ms'] as int,
      r.first['duration_ms'] as int,
    );
  }

  /// Started (past 30 s) and not finished (under 95%), most recent first.
  List<Channel> continueWatching({int limit = 20}) => _channels(
    "SELECT $_cols FROM progress p JOIN streams s ON s.type=p.type AND s.id=p.id "
    "WHERE s.type='movie' AND p.position_ms >= 30000 "
    "AND (p.duration_ms <= 0 OR p.position_ms * 1.0 / p.duration_ms <= 0.95) "
    "ORDER BY p.updated_at DESC LIMIT ?",
    [limit],
  );

  /// Episodes of one series, ordered by season, episode, then provider order.
  List<Episode> episodes(String group, String name) => _db
      .select(
        "SELECT $_cols, s.season, s.episode FROM streams s "
        "WHERE s.type='series' AND s.grp=? AND s.series_name=? "
        "ORDER BY s.season, s.episode, s.rowid",
        [group, name],
      )
      .map((r) => Episode(_channel(r), r['season'] as int, r['episode'] as int))
      .toList();

  List<SeriesSummary> _summaries(String sql, List<Object?> args) => _db
      .select(sql, args)
      .map(
        (r) => SeriesSummary(
          r['grp'] as String,
          r['series_name'] as String,
          r['poster'] as String,
          r['seasons'] as int,
          r['episodes'] as int,
        ),
      )
      .toList();

  List<SeriesSummary> seriesIn(String group) => _summaries(
    "SELECT $_summaryCols FROM streams s WHERE s.type='series' AND s.grp=? "
    "GROUP BY s.series_name ORDER BY s.series_name COLLATE NOCASE",
    [group],
  );

  int seriesCount(String group) =>
      _db.select(
            "SELECT COUNT(DISTINCT series_name) AS n FROM streams "
            "WHERE type='series' AND grp=?",
            [group],
          ).first['n']
          as int;

  List<SeriesSummary> seriesFavorites() => _summaries(
    "SELECT $_summaryCols FROM series_favorites f JOIN streams s "
    "ON s.type='series' AND s.grp=f.grp AND s.series_name=f.series_name "
    "GROUP BY s.grp, s.series_name ORDER BY s.series_name COLLATE NOCASE",
    const [],
  );

  bool isSeriesFavorite(String group, String name) => _db.select(
    'SELECT 1 FROM series_favorites WHERE grp=? AND series_name=?',
    [group, name],
  ).isNotEmpty;

  void setSeriesFavorite(String group, String name, bool value) {
    if (value) {
      _db.execute(
        'INSERT OR IGNORE INTO series_favorites(grp,series_name) VALUES(?,?)',
        [group, name],
      );
    } else {
      _db.execute(
        'DELETE FROM series_favorites WHERE grp=? AND series_name=?',
        [group, name],
      );
    }
  }

  /// One entry per series with any episode progress, newest first, minus the
  /// ones the user removed and has not watched since.
  List<SeriesSummary> continueSeries({int limit = 20}) => _summaries(
    "WITH w AS ("
    " SELECT s.grp AS g, s.series_name AS n, MAX(p.updated_at) AS last"
    " FROM progress p JOIN streams s ON s.type=p.type AND s.id=p.id"
    " WHERE s.type='series' GROUP BY s.grp, s.series_name) "
    "SELECT $_summaryCols FROM w JOIN streams s "
    "ON s.type='series' AND s.grp=w.g AND s.series_name=w.n "
    "WHERE NOT EXISTS (SELECT 1 FROM series_hidden h "
    " WHERE h.grp=w.g AND h.series_name=w.n AND h.hidden_at >= w.last) "
    "GROUP BY w.g, w.n ORDER BY w.last DESC LIMIT ?",
    [limit],
  );

  void hideSeries(String group, String name, DateTime at) => _db.execute(
    'INSERT INTO series_hidden(grp,series_name,hidden_at) VALUES(?,?,?) '
    'ON CONFLICT(grp,series_name) DO UPDATE SET hidden_at=excluded.hidden_at',
    [group, name, at.millisecondsSinceEpoch],
  );

  /// Marks an item as watched now without touching its resume position.
  void touchProgress(String type, String id, DateTime at) => _db.execute(
    'INSERT INTO progress(type,id,position_ms,duration_ms,updated_at) '
    'VALUES(?,?,0,0,?) '
    'ON CONFLICT(type,id) DO UPDATE SET updated_at=excluded.updated_at',
    [type, id, at.millisecondsSinceEpoch],
  );

  (Channel, Progress)? lastWatched(String group, String name) {
    final r = _db.select(
      "SELECT $_cols, p.position_ms, p.duration_ms FROM progress p "
      "JOIN streams s ON s.type=p.type AND s.id=p.id "
      "WHERE s.type='series' AND s.grp=? AND s.series_name=? "
      "ORDER BY p.updated_at DESC LIMIT 1",
      [group, name],
    );
    if (r.isEmpty) return null;
    return (
      _channel(r.first),
      Progress(r.first['position_ms'] as int, r.first['duration_ms'] as int),
    );
  }

  Channel _channel(Row r) => Channel(
    type: r['type'] as String,
    id: r['id'] as String,
    name: r['name'] as String,
    group: r['grp'] as String,
    logo: r['logo'] as String,
    url: r['url'] as String,
  );

  List<Channel> _channels(String sql, List<Object?> args) =>
      _db.select(sql, args).map(_channel).toList();
}
