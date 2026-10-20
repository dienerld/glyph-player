import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/resume.dart';
import '../../data/series_nav.dart';
import '../../data/tmdb_info.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../movies/vod_player_page.dart';
import '../shared/tmdb_display.dart';
import 'series_card.dart';

class SeriesPage extends ConsumerStatefulWidget {
  const SeriesPage({super.key, required this.summary});
  final SeriesSummary summary;

  @override
  ConsumerState<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends ConsumerState<SeriesPage> {
  int? _season;

  SeriesSummary get _s => widget.summary;

  Future<void> _play(List<Episode> eps, int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VodPlayerPage(
          queue: [for (final e in eps) e.item],
          index: index,
          nextOf: (k) => nextIndex(eps, k),
          previousOf: (k) => previousIndex(eps, k),
        ),
      ),
    );
    ref.invalidate(continueSeriesProvider);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final episodes = ref.watch(seriesEpisodesProvider((_s.group, _s.name)));
    final fav = db.isSeriesFavorite(_s.group, _s.name);
    final tmdbInfo = ref.watch(tmdbSeriesProvider(_s.name)).value;
    final overview = tmdbInfo?.overview.trim() ?? '';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        toolbarHeight: 72,
        actions: [
          IconButton(
            tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
            icon: Icon(
              fav ? Icons.star : Icons.star_border,
              color: fav ? Tokens.accent : null,
            ),
            onPressed: () {
              db.setSeriesFavorite(_s.group, _s.name, !fav);
              ref.invalidate(seriesFavoritesProvider);
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: episodes.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (eps) {
          if (eps.isEmpty) return const Center(child: Text('Sem episódios'));
          final lw = db.lastWatched(_s.group, _s.name);
          final lastIdx = lw == null
              ? -1
              : eps.indexWhere((e) => e.item.id == lw.$1.id);
          final target = lastIdx < 0 ? 0 : continueIndex(eps, lastIdx, lw!.$2);
          final seasons = {for (final e in eps) e.season}.toList()..sort();
          final selected = _season ?? eps[target].season;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Tokens.radius),
                        child: Poster(
                          url: posterUrl(
                            _s.poster,
                            tmdbInfo,
                            TmdbImageSize.card,
                          ),
                          name: _s.name,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${distributorLabel(_s.group)} · ${seasonsLabel(_s.seasons)} · ${_s.episodes} episódios',
                                style: const TextStyle(color: Tokens.textDim),
                              ),
                              RatingChip(rating: tmdbInfo?.rating),
                            ],
                          ),
                          if (overview.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Text(
                                overview,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Tokens.text,
                                  fontSize: 14,
                                  height: 20 / 14,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: Text(lw == null ? 'Assistir' : 'Continuar'),
                            onPressed: () => _play(eps, target),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final n in seasons)
                      ChoiceChip(
                        label: Text('T$n'),
                        selected: n == selected,
                        onSelected: (_) => setState(() => _season = n),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (var i = 0; i < eps.length; i++)
                      if (eps[i].season == selected)
                        _EpisodeTile(
                          episode: eps[i],
                          progress: db.progressOf('series', eps[i].item.id),
                          onTap: () => _play(eps, i),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.progress,
    required this.onTap,
  });
  final Episode episode;
  final Progress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final done = p != null && isFinished(p.positionMs, p.durationMs);
    final partial = p != null && !done && p.durationMs > 0 && p.positionMs > 0;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Text(
        'E${episode.episode.toString().padLeft(2, '0')}',
        style: const TextStyle(
          fontFamily: Tokens.display,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      title: Text(
        episode.item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: partial
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: (p.positionMs / p.durationMs).clamp(0.0, 1.0),
                minHeight: 3,
                color: Tokens.accent,
                backgroundColor: Tokens.line,
              ),
            )
          : null,
      trailing: done
          ? const Icon(Icons.check_circle, color: Tokens.accent)
          : null,
    );
  }
}
