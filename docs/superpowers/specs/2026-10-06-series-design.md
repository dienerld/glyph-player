# Glyph Player — Series Design

## Goal
Browse and watch series from the playlist: grouped by distributor, then series → season → episode, with a saved Favorites list, a Continue list (with remove) and auto-advance to the next episode. Builds on the Live and Movies features (already in `main`).

## Reference data (user's real list, 2026-10-06)
- 198,622 series episodes, all with the name pattern `<Series> S<ss>E<ee>` (0 unparsed).
- 5,510 series keyed by (group, series name); 5,477 distinct names (33 appear under two groups).
- Distributor is the group: `Series | Netflix`, `Series | Disney+`, `Series | HBO Max`, … Groups without the `Series | ` prefix are collections: `Novelas`, `Novelas Turcas`, `Doramas`, `Doramas Viki`, `Mini Series (shorts)`; `Series | Outros Streamings` and `Series | Legendados` are regular groups.
- 5,500 of 5,510 series have a poster (`tvg-logo`, TMDB, same for all episodes of a series).
- Largest series: 828 episodes, 37 seasons. 2 episodes use season 0.
- 1,692 (season, episode) pairs occur twice inside one series (different stream ids).

## Decisions (user-approved)
- Unit for Favorites and Continue is the **series** (not the episode).
- Series without a distributor prefix are shown as their own sections beside the distributors.
- Compute series/season/episode **once at import** into indexed columns (not at query time).
- Adult filter applies (reuses `isAdultGroup`).
- Out of scope: manual distributor assignment, EPG, sync.

## Data
- `streams` gains `series_name TEXT NOT NULL DEFAULT ''`, `season INTEGER NOT NULL DEFAULT 0`, `episode INTEGER NOT NULL DEFAULT 0`; index on `(type, grp, series_name)`. Filled only for `type='series'`.
- `parseSeriesName(String) -> (name, season, episode)?` (pure): regex `^(.*?)\s*[Ss](\d+)\s*[Ee](\d+)`, case-insensitive; a name that does not match yields a null and the episode is stored under series name = full name, season 0, episode 0 (never dropped).
- `StreamEntry` and the importer carry the three fields; the upsert writes them.
- **Migration** (`PRAGMA user_version` 0 → 1) on open: `ALTER TABLE` adds the columns, then one transaction fills them for existing series rows with the same parser. No re-download.
- New tables: `series_favorites(grp, series_name, PRIMARY KEY(grp, series_name))`; `series_hidden(grp, series_name, hidden_at, PRIMARY KEY(grp, series_name))`.
- Series key = `(grp, series_name)`. Distributor label = group with the `Series | ` prefix removed; sections = distinct series groups in provider order, with series counts.
- Queries: `seriesSections()`, `seriesIn(group)` (series name, poster, season count, episode count), `seasons(group, name)`, `episodes(group, name, season)`, `continueSeries()`, `seriesFavorites()`, `setSeriesFavorite`, `hideSeries`.
- **Duplicates (user decision, may be revisited after manual review of `duplicados-series.csv`):** all duplicate rows stay visible in the episode list (ordered by season, episode, rowid). Auto-advance and Continue skip rows whose (season, episode) equals the current one.
- **Continue:** the most recent progress per series (existing `progress` table, `type='series'`), excluding series whose latest progress time is not after `hidden_at`. Target episode = the last watched one if under 95%; otherwise the next episode by (season, episode); if none, the last watched one. Resume position uses the existing `resumePosition`.

## UI (same visual direction as Live/Movies; posters used for series)
- Rail gets **Séries**. Home: rows **Continuar assistindo** (card menu "Remover da lista") and **Favoritos**, then a grid of distributor/section tiles (label, series count, tinted like movie categories).
- Section → grid of poster cards (poster, title, "N temporadas"; monogram if no poster).
- Series page: poster, title, ⭐ favorite, primary button (**Continuar** or **Assistir**), season selector, episode list with watched check and progress bar.
- Empty states follow Live/Movies. Settings unchanged.

## Player
- The movie player becomes a VOD player taking `items` (episode queue) and `index`; a movie is a queue of one. Progress saving/resume unchanged, per item.
- At the end of an episode (`player.stream.completed`) an overlay "Próximo episódio em 5 s" with **Assistir agora** and **Cancelar** appears; when the countdown ends the next episode opens. No next episode: nothing happens. Opening an episode marks the series as watched now (re-shows it in Continue).

## Risks
1. Migration of a populated DB (198k rows) must be quick and idempotent.
2. The series poster is a remote image; failures fall back to a monogram.
3. Auto-advance depends on the `completed` event firing for these streams.
4. Windows untested.

## Testing
Parser (normal, case, spacing, no-match), migration (old schema → new, idempotent), series queries (sections/counts, seasons, episodes, duplicates), continue-target rule (mid-episode, finished → next, last episode, hidden then re-watched), favorites, widget tests for the home, section grid, series page and the auto-advance overlay logic (pure `nextEpisode` function tested directly).
