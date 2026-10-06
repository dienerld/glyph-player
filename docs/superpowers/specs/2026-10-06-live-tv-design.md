# Glyph Player — Live TV (v1) Design

## Goal
Desktop IPTV player (Linux + Windows) replacing Hypnotix for a personal M3U_plus list of 50 MB+. v1 delivers **Live TV only**. Movies, series (grouped by distributor), watch history for VOD and auto-advance come later, each with its own spec.

## Problems solved (vs. Hypnotix)
- List update must never freeze the UI.
- Correct categories.
- Watch history (live: recents) and favorites.
- Performance with ~220k entries.

## Reference data (user's real list, 2026-10-06)
219,314 entries, 55.5 MB, CRLF line endings. By stream URL: `/live/` 3,326 · `/movie/` 17,366 · `/series/` 198,622. All entries carry `tvg-id` (empty), `tvg-name`, `tvg-logo`, `group-title`. Type is decided by URL path, never by group name (e.g. `Canais | Disney+` is live, not a series).

## Scope
In: playlist import/update from a stored URL, live categories, search, recents, favorites, embedded playback, zapping.
Out: EPG, movies, series, distributors, auto-advance, multiple lists, any remote API other than the playlist URL itself.

## Stack
Flutter (stable, Dart), platforms `linux` and `windows` only. `media_kit` (libmpv) for playback. SQLite with FTS5 for storage and search. Riverpod for state. Playlist URL stored in the OS secure store (libsecret on Linux, Credential Manager on Windows), not in SQLite.

## Architecture
```
lib/
  data/      parser, db (schema, queries), importer
  features/live/   home rows, search, zapping panel
  player/    media_kit wrapper
  ui/theme/  design tokens
```

### Import / update
1. Download to a temp file (streamed to disk, never held in memory).
2. A Dart `Isolate` parses the file line by line (handles CRLF, empty attributes, quoted commas) and upserts in batched transactions, keyed by the numeric stream id from the URL.
3. Rows not seen in the run are removed after it completes.
4. UI reads the DB throughout; progress is reported over a port. The UI thread never parses or waits.
All types are stored (cheap, avoids re-import when VOD is added); only live is surfaced.

### Data
- `streams(id, type, name, group, logo, url)`; FTS5 index on `name`.
- `favorites(stream_id)`, `recents(stream_id, watched_at)` — independent tables, survive updates.
- Category = `group-title` with the `Canais | ` prefix stripped.

### UI
Netflix/Prime-style: left rail, top search, home as horizontal category rows (Recentes, Favoritos, one per group) with logo+name cards. Opening a channel goes full-screen player with a slide-over zapping panel (↑/↓ switch channel, current category listed). Visual direction defined with the `impeccable` and `frontend-design` skills before building UI.

### Player
`media_kit` rendering libmpv into a Flutter texture (works on Wayland; no `--wid`).

## Risks
1. **Embedded mpv on Wayland/KDE** — validated first; if it fails, choose a fallback before building UI.
2. Windows cannot be tested from the dev machine; verified on Linux only until run on Windows.
3. Stream id stability across provider updates is unconfirmed; recents/favorites depend on it.
4. Playlist credentials live in every stream URL inside the DB; the DB is local and must not be committed or exported.

## Testing
- Parser unit tests with real lines (CRLF, empty `tvg-id`, commas in names).
- Importer test on a fixture (insert, update, removal of vanished rows).
- Benchmark on the real list: import time, peak memory, UI frame times during import.
- Manual playback check on Linux/Wayland.
