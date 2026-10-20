import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/movie_title.dart';
import '../../data/tmdb_info.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../shared/cached_thumb.dart';
import '../shared/item_expansion.dart';
import '../shared/monogram.dart';
import '../shared/tmdb_attribution.dart';
import '../shared/tmdb_display.dart';
import 'movie_routes.dart';
import 'movie_tag.dart';

const noOverviewText = 'Sem resumo disponível.';
const loadingOverviewText = 'Buscando o resumo…';

/// Identity of a movie in an expandable list.
Object movieKey(Channel m) => m.id;

/// The details accordion of a movie grid (`PagedGrid.panel`).
final movieGridPanel = ItemPanel<Channel>(
  keyOf: movieKey,
  builder: (_, m, maxHeight, close) =>
      MovieDetailsPanel(movie: m, maxHeight: maxHeight, onClose: close),
);

/// Opens in the list, right below the row of the tapped movie card, when a
/// TMDB key is set: poster, title, year, rating and synopsis, with "Assistir".
/// It reads the same lookup the card does, so without data (loading, not
/// found, offline) it still shows the title and the button. "Assistir" takes
/// the focus when it opens.
class MovieDetailsPanel extends ConsumerStatefulWidget {
  const MovieDetailsPanel({
    super.key,
    required this.movie,
    required this.maxHeight,
    required this.onClose,
  });
  final Channel movie;

  /// Tallest it may be; the synopsis scrolls inside when it does not fit.
  final double maxHeight;
  final VoidCallback onClose;

  @override
  ConsumerState<MovieDetailsPanel> createState() => _MovieDetailsPanelState();
}

class _MovieDetailsPanelState extends ConsumerState<MovieDetailsPanel> {
  final _play = FocusNode(debugLabel: 'Assistir');

  Channel get _m => widget.movie;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _play.requestFocus();
    });
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  void _watch() => Navigator.of(context).push(moviePlayerRoute(ref, _m));

  void _toggleFavorite(bool value) {
    ref.read(dbProvider).setFavorite(_m.type, _m.id, value);
    ref.invalidate(movieFavoritesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = parseMovieTitle(_m.name);
    final lookup = ref.watch(tmdbMovieProvider(tmdbMovieQuery(_m.name)));
    final info = lookup.value;
    final loading = lookup.isLoading && info == null;
    // The card's star changes the same favorite: follow it.
    ref.watch(movieFavoritesProvider);
    final fav = ref.read(dbProvider).isFavorite(_m.type, _m.id);
    final poster = posterUrl(_m.logo, info, TmdbImageSize.details);

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
              icon: Icon(
                fav ? Icons.star : Icons.star_border,
                color: fav ? Tokens.accent : null,
              ),
              onPressed: () => _toggleFavorite(!fav),
            ),
            IconButton(
              tooltip: 'Fechar',
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (t.year != null)
              Text(
                '${t.year}',
                style: const TextStyle(color: Tokens.textDim, fontSize: 14),
              ),
            for (final tag in t.tags) MovieTag(tag),
            RatingChip(rating: info?.rating),
          ],
        ),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            child: _Overview(
              text: info?.overview.trim() ?? '',
              loading: loading,
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          focusNode: _play,
          style: FilledButton.styleFrom(minimumSize: const Size(168, 48)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Assistir'),
          onPressed: _watch,
        ),
        const SizedBox(height: 20),
        const TmdbAttribution(),
      ],
    );

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Tokens.ink.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(Tokens.radius),
            border: Border.all(color: Tokens.line.withValues(alpha: 0.6)),
          ),
          child: LayoutBuilder(
            builder: (_, c) {
              final posterWidth = c.maxWidth >= 600 ? 160.0 : 104.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: posterWidth,
                    child: _Poster(url: poster, title: t.title),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radius),
        child: Stack(
          children: [
            // The poster is the backdrop: softened and dimmed so the card on
            // top stays readable, whatever the artwork looks like.
            if (poster.isNotEmpty)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 14,
                    sigmaY: 14,
                    tileMode: TileMode.decal,
                  ),
                  child: CachedThumb(
                    url: poster,
                    cacheWidth: 1000,
                    fit: BoxFit.contain,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ),
            Positioned.fill(
              child: ColoredBox(color: Tokens.ink.withValues(alpha: 0.5)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: card,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.title});
  final String url, title;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 2 / 3,
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Tokens.tile,
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
      child: CachedThumb(
        url: url,
        cacheWidth: 520,
        fallback: Center(child: Monogram(name: title, size: 40)),
      ),
    ),
  );
}

/// The synopsis; dim placeholders while loading and when there is none.
class _Overview extends StatelessWidget {
  const _Overview({required this.text, required this.loading});
  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final String shown;
    final Color color;
    if (text.isNotEmpty) {
      shown = text;
      color = Tokens.text;
    } else {
      shown = loading ? loadingOverviewText : noOverviewText;
      color = Tokens.textDim;
    }
    return Text(
      shown,
      style: TextStyle(color: color, fontSize: 15, height: 24 / 15),
    );
  }
}
