import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/movie_title.dart';
import '../../data/tmdb_info.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../shared/cached_thumb.dart';
import '../shared/monogram.dart';
import '../shared/tmdb_attribution.dart';
import '../shared/tmdb_display.dart';
import 'movie_routes.dart';
import 'movie_tag.dart';

const noOverviewText = 'Sem resumo disponível.';

/// Between a movie card and the player when a TMDB key is set: poster, title,
/// year, rating and synopsis, with "Assistir". It reads the same lookup the
/// card does, so without data (loading, not found, offline) it still shows the
/// title and the button.
class MovieDetailsPage extends ConsumerStatefulWidget {
  const MovieDetailsPage({super.key, required this.movie});
  final Channel movie;

  @override
  ConsumerState<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends ConsumerState<MovieDetailsPage> {
  Channel get _m => widget.movie;

  void _play() => Navigator.of(context).push(moviePlayerRoute(ref, _m));

  void _toggleFavorite(bool value) {
    ref.read(dbProvider).setFavorite(_m.type, _m.id, value);
    ref.invalidate(movieFavoritesProvider);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = parseMovieTitle(_m.name);
    final lookup = ref.watch(tmdbMovieProvider(tmdbMovieQuery(_m.name)));
    final info = lookup.value;
    final loading = lookup.isLoading && info == null;
    final fav = ref.read(dbProvider).isFavorite(_m.type, _m.id);
    final poster = posterUrl(_m.logo, info, TmdbImageSize.details);

    final posterBox = AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Tokens.tile,
          borderRadius: BorderRadius.circular(Tokens.radius),
        ),
        child: CachedThumb(
          url: poster,
          cacheWidth: 520,
          fallback: Center(child: Monogram(name: t.title, size: 56)),
        ),
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
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
        const SizedBox(height: 20),
        _Overview(text: info?.overview.trim() ?? '', loading: loading),
        const SizedBox(height: 28),
        FilledButton.icon(
          autofocus: true,
          style: FilledButton.styleFrom(minimumSize: const Size(168, 48)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Assistir'),
          onPressed: _play,
        ),
        const SizedBox(height: 36),
        const TmdbAttribution(),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Voltar',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          toolbarHeight: 72,
          actions: [
            IconButton(
              tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
              icon: Icon(
                fav ? Icons.star : Icons.star_border,
                color: fav ? Tokens.accent : null,
              ),
              onPressed: () => _toggleFavorite(!fav),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The poster is the backdrop: softened and dimmed so the card on
            // top stays readable, whatever the artwork looks like.
            if (poster.isNotEmpty)
              ImageFiltered(
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
            ColoredBox(color: Tokens.ink.withValues(alpha: 0.5)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Tokens.radius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Tokens.ink.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(Tokens.radius),
                            border: Border.all(
                              color: Tokens.line.withValues(alpha: 0.6),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (_, c) => c.maxWidth >= 600
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 240, child: posterBox),
                                      const SizedBox(width: 32),
                                      Expanded(child: details),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 180, child: posterBox),
                                      const SizedBox(height: 24),
                                      details,
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      shown = loading ? 'Buscando o resumo…' : noOverviewText;
      color = Tokens.textDim;
    }
    return Text(
      shown,
      style: TextStyle(color: color, fontSize: 15, height: 24 / 15),
    );
  }
}
