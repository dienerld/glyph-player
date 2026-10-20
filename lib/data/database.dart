import 'package:sqlite3/sqlite3.dart';

import 'content_filter.dart';
import 'natural_compare.dart';
import 'series_title.dart';
import 'stream_entry.dart';
import 'title_fold.dart';
import 'tmdb_info.dart';

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

/// Title search: `title` feeds the trigram index (substring search); `norm`
/// is the title folded by [foldTitle], for prefix search with LIKE.
const _titlesTable = '''
CREATE VIRTUAL TABLE IF NOT EXISTS titles_fts USING fts5(
  title, kind UNINDEXED, grp UNINDEXED, last UNINDEXED, norm UNINDEXED,
  tokenize='trigram remove_diacritics 1');''';

const _schema =
    '''
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
$_titlesTable
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
CREATE TABLE IF NOT EXISTS continue_hidden(
  type TEXT NOT NULL, id TEXT NOT NULL, hidden_at INTEGER NOT NULL,
  PRIMARY KEY(type, id));
CREATE TABLE IF NOT EXISTS recents(
  type TEXT NOT NULL, id TEXT NOT NULL, watched_at INTEGER NOT NULL,
  PRIMARY KEY(type, id));
CREATE TABLE IF NOT EXISTS tmdb_cache(
  kind TEXT NOT NULL, title_key TEXT NOT NULL, year INTEGER NOT NULL,
  tmdb_id INTEGER, poster TEXT, rating REAL, overview TEXT NOT NULL DEFAULT '',
  fetched_at INTEGER NOT NULL,
  PRIMARY KEY(kind, title_key, year));
''';

/// How many recently watched channels are kept per type; older ones fall off.
const recentsLimit = 20;

const _summaryCols =
    's.grp, s.series_name, MAX(s.logo) AS poster, '
    'COUNT(DISTINCT s.season) AS seasons, COUNT(*) AS episodes';

const _cols = 's.type, s.id, s.name, s.grp, s.logo, s.url';

/// Order of a movie or series category grid. [recent] is newest imported
/// first: upserts keep a row's rowid, so new items carry the highest ones.
enum SortOrder { recent, az, za }

/// Items per page in the movie and series category grids.
const gridPageSize = 60;

String _movieOrder(SortOrder o) => switch (o) {
  SortOrder.recent => 's.rowid DESC',
  SortOrder.az => 's.name COLLATE NOCASE ASC, s.rowid ASC',
  SortOrder.za => 's.name COLLATE NOCASE DESC, s.rowid DESC',
};

String _seriesOrder(SortOrder o) => switch (o) {
  SortOrder.recent => 'MAX(s.rowid) DESC',
  SortOrder.az => 's.series_name COLLATE NOCASE ASC, MIN(s.rowid) ASC',
  SortOrder.za => 's.series_name COLLATE NOCASE DESC, MIN(s.rowid) DESC',
};

/// The `titles_fts` condition for a title search and its argument, or null
/// for an empty [query]. One or two characters match the start of the title
/// (the trigram index needs three); more match anywhere in it. Both ignore
/// case and accents, and treat FTS and LIKE operators as plain text.
(String, String)? _titleFilter(String query) {
  final t = query.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return null;
  if (t.runes.length < 3) {
    final like = foldTitle(
      t,
    ).replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
    return ("norm LIKE ? ESCAPE '\\'", '$like%');
  }
  return ('titles_fts MATCH ?', '"${t.replaceAll('"', '""')}"');
}

/// Excludes the groups [isAdultGroup] flags (LIKE is case-insensitive).
String _notAdult(String column) =>
    adultGroupWords.map((w) => "$column NOT LIKE '%$w%'").join(' AND ');

/// [_seriesOrder] over `titles_fts` rows, whose rowid is a series' first
/// episode and `last` its newest one.
String _titleOrder(SortOrder o) => switch (o) {
  SortOrder.recent => 'last DESC',
  SortOrder.az => 'title COLLATE NOCASE ASC, rowid ASC',
  SortOrder.za => 'title COLLATE NOCASE DESC, rowid DESC',
};

class Db {
  Db._(this._db) {
    _db.execute(
      'PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; PRAGMA synchronous=NORMAL;',
    );
    _db.createFunction(
      functionName: 'fold_title',
      function: (args) => foldTitle(args[0] as String),
      argumentCount: const AllowedArgumentCount(1),
      deterministic: true,
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
    final titleCols = _db
        .select('PRAGMA table_info(titles_fts)')
        .map((r) => r['name'] as String)
        .toSet();
    if (!titleCols.contains('norm')) {
      // Built before prefix search: recreate it, the check below refills it.
      _db.execute('DROP TABLE titles_fts');
      _db.execute(_titlesTable);
    }
    final titlesEmpty = _db.select('SELECT 1 FROM titles_fts LIMIT 1').isEmpty;
    if (titlesEmpty &&
        _db
            .select(
              "SELECT 1 FROM streams WHERE type IN ('movie','series') LIMIT 1",
            )
            .isNotEmpty) {
      _rebuildTitles();
    }
    _db.execute('PRAGMA user_version = 1');
  }

  /// Refills the title index: one row per movie and one per (group, series),
  /// not per episode. Every rowid is a `streams` rowid, the movie's own or a
  /// series' first episode (`last` holds its newest), so movies join by rowid
  /// and series by (grp, title), and series can be paged in the index alone.
  void _rebuildTitles() {
    _db.execute('BEGIN');
    try {
      _db.execute('DELETE FROM titles_fts');
      _db.execute(
        "INSERT INTO titles_fts(rowid, title, kind, grp, last, norm) "
        "SELECT rowid, name, 'movie', '', rowid, fold_title(name) "
        "FROM streams WHERE type='movie'",
      );
      _db.execute(
        "INSERT INTO titles_fts(rowid, title, kind, grp, last, norm) "
        "SELECT MIN(rowid), series_name, 'series', grp, MAX(rowid), "
        "fold_title(series_name) "
        "FROM streams WHERE type='series' GROUP BY grp, series_name",
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
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

  /// Drops rows not seen in [run] and rebuilds the search indexes. Call only
  /// after a fully successful import.
  void finishRun(int run) {
    _db.execute('DELETE FROM streams WHERE run <> ?', [run]);
    _db.execute("INSERT INTO streams_fts(streams_fts) VALUES('rebuild')");
    _rebuildTitles();
  }

  List<GroupCount> groups(String type) => _db
      .select(
        'SELECT grp, COUNT(*) AS n FROM streams WHERE type=? GROUP BY grp ORDER BY MIN(rowid)',
        [type],
      )
      .map((r) => GroupCount(r['grp'] as String, r['n'] as int))
      .toList();

  /// A group's channels in natural name order (`Canal 2` before `Canal 10`).
  List<Channel> channels(String type, String group) => _channels(
    "SELECT $_cols FROM streams s WHERE s.type=? AND s.grp=? ORDER BY s.rowid",
    [type, group],
  )..sort((a, b) => naturalCompare(a.name, b.name));

  /// One page of movies: of [group], or of every category when null. A
  /// non-empty [query] keeps only matching titles: one or two characters
  /// match the start of the name, more match anywhere in it, ignoring case
  /// and accents. [hideAdult] drops the groups [isAdultGroup] flags.
  List<Channel> moviesPage(
    String? group,
    SortOrder order, {
    String query = '',
    bool hideAdult = false,
    int limit = gridPageSize,
    int offset = 0,
  }) {
    final where = ["s.type='movie'"];
    final args = <Object?>[];
    if (group != null) {
      where.add('s.grp=?');
      args.add(group);
    }
    if (hideAdult) where.add(_notAdult('s.grp'));
    final title = _titleFilter(query);
    if (title != null) {
      where.add(
        "s.rowid IN (SELECT rowid FROM titles_fts "
        "WHERE ${title.$1} AND kind='movie')",
      );
      args.add(title.$2);
    }
    return _channels(
      "SELECT $_cols FROM streams s WHERE ${where.join(' AND ')} "
      "ORDER BY ${_movieOrder(order)} LIMIT ? OFFSET ?",
      [...args, limit, offset],
    );
  }

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

  List<Channel> favorites(String type) => _channels(
    "SELECT $_cols FROM favorites f JOIN streams s ON s.type=f.type AND s.id=f.id "
    "WHERE s.type=? ORDER BY s.name COLLATE NOCASE",
    [type],
  );

  List<Channel> recents({int limit = recentsLimit}) => _channels(
    "SELECT $_cols FROM recents r JOIN streams s ON s.type=r.type AND s.id=r.id "
    "WHERE s.type='live' ORDER BY r.watched_at DESC LIMIT ?",
    [limit],
  );

  /// Drops a channel from the recents list; watching it again brings it back.
  void removeRecent(String type, String id) =>
      _db.execute('DELETE FROM recents WHERE type=? AND id=?', [type, id]);

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

  /// Records a watch and keeps only the last [recentsLimit] per type, so
  /// removing one entry never brings back an older one.
  void markWatched(String type, String id, DateTime at) {
    _db.execute(
      'INSERT INTO recents(type,id,watched_at) VALUES(?,?,?) '
      'ON CONFLICT(type,id) DO UPDATE SET watched_at=excluded.watched_at',
      [type, id, at.millisecondsSinceEpoch],
    );
    _db.execute(
      'DELETE FROM recents WHERE type=? AND id NOT IN '
      '(SELECT id FROM recents WHERE type=? ORDER BY watched_at DESC LIMIT ?)',
      [type, type, recentsLimit],
    );
  }

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
    "AND NOT EXISTS (SELECT 1 FROM continue_hidden h "
    " WHERE h.type=p.type AND h.id=p.id AND h.hidden_at >= p.updated_at) "
    "ORDER BY p.updated_at DESC LIMIT ?",
    [limit],
  );

  /// Hides an item from Continue without touching its resume position; it
  /// returns when the item is watched again.
  void hideContinue(String type, String id, DateTime at) => _db.execute(
    'INSERT INTO continue_hidden(type,id,hidden_at) VALUES(?,?,?) '
    'ON CONFLICT(type,id) DO UPDATE SET hidden_at=excluded.hidden_at',
    [type, id, at.millisecondsSinceEpoch],
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

  /// One page of series, one entry per (group, series): of [group], or of
  /// every category when null. [query] matches the series name (not episode
  /// titles) like in [moviesPage]; [hideAdult] likewise.
  List<SeriesSummary> seriesPage(
    String? group,
    SortOrder order, {
    String query = '',
    bool hideAdult = false,
    int limit = gridPageSize,
    int offset = 0,
  }) {
    final title = _titleFilter(query);
    if (title != null) {
      // Pages in the index first, so only the page's episodes are summed.
      final where = [title.$1, "kind='series'"];
      final args = <Object?>[title.$2];
      if (group != null) {
        where.add('grp=?');
        args.add(group);
      }
      if (hideAdult) where.add(_notAdult('grp'));
      return _summaries(
        "WITH page AS (SELECT grp AS g, title AS n FROM titles_fts "
        "WHERE ${where.join(' AND ')} ORDER BY ${_titleOrder(order)} "
        "LIMIT ? OFFSET ?) "
        "SELECT $_summaryCols FROM page JOIN streams s "
        "ON s.type='series' AND s.grp=page.g AND s.series_name=page.n "
        "GROUP BY s.grp, s.series_name ORDER BY ${_seriesOrder(order)}",
        [...args, limit, offset],
      );
    }
    final where = ["s.type='series'"];
    final args = <Object?>[];
    if (group != null) {
      where.add('s.grp=?');
      args.add(group);
    }
    if (hideAdult) where.add(_notAdult('s.grp'));
    return _summaries(
      "SELECT $_summaryCols FROM streams s WHERE ${where.join(' AND ')} "
      "GROUP BY s.grp, s.series_name ORDER BY ${_seriesOrder(order)} "
      "LIMIT ? OFFSET ?",
      [...args, limit, offset],
    );
  }

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

  /// The cached TMDB lookup for [titleKey] (see [tmdbTitleKey]) of [kind]
  /// ([TmdbKind]), whatever its age; null when never looked up. [year] 0
  /// means unknown.
  TmdbCached? tmdbCached(TmdbKind kind, String titleKey, {int year = 0}) {
    final r = _db.select(
      'SELECT tmdb_id, poster, rating, overview, fetched_at FROM tmdb_cache '
      'WHERE kind=? AND title_key=? AND year=?',
      [kind.name, titleKey, year],
    );
    if (r.isEmpty) return null;
    final row = r.first;
    final id = row['tmdb_id'] as int?;
    return TmdbCached(
      id == null
          ? null
          : TmdbInfo(
              id: id,
              posterPath: row['poster'] as String?,
              rating: (row['rating'] as num?)?.toDouble(),
              overview: row['overview'] as String,
            ),
      DateTime.fromMillisecondsSinceEpoch(row['fetched_at'] as int),
    );
  }

  /// Stores a TMDB answer: [info], or null for "not found".
  void putTmdb(
    TmdbKind kind,
    String titleKey,
    TmdbInfo? info,
    DateTime at, {
    int year = 0,
  }) => _db.execute(
    'INSERT INTO tmdb_cache'
    '(kind,title_key,year,tmdb_id,poster,rating,overview,fetched_at) '
    'VALUES(?,?,?,?,?,?,?,?) '
    'ON CONFLICT(kind,title_key,year) DO UPDATE SET tmdb_id=excluded.tmdb_id, '
    'poster=excluded.poster, rating=excluded.rating, '
    'overview=excluded.overview, fetched_at=excluded.fetched_at',
    [
      kind.name,
      titleKey,
      year,
      info?.id,
      info?.posterPath,
      info?.rating,
      info?.overview ?? '',
      at.millisecondsSinceEpoch,
    ],
  );

  /// Forgets every TMDB answer (Settings, "Limpar cache").
  void clearTmdbCache() => _db.execute('DELETE FROM tmdb_cache');

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
