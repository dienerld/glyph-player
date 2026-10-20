import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/movie_title.dart';
import '../../data/tmdb_info.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../shared/cached_thumb.dart';
import '../shared/card_actions.dart';
import '../shared/tmdb_display.dart';
import 'movie_details_page.dart';
import 'movie_routes.dart';
import 'movie_tag.dart';

/// Where a tap on a [MovieCard] goes.
enum MovieOpen {
  /// The details screen when a TMDB key is set, the player otherwise.
  details,

  /// Straight to the player: resuming a movie (Continuar assistindo).
  player,
}

/// Typographic card: most movies have no poster, so the title leads. With a
/// TMDB key it also shows the TMDB poster (when the list has none) and the
/// rating once they are known.
class MovieCard extends ConsumerStatefulWidget {
  const MovieCard({
    super.key,
    required this.movie,
    this.open = MovieOpen.details,
    this.progress,
    this.onRemove,
  });
  final Channel movie;

  /// What a tap opens; see [MovieOpen].
  final MovieOpen open;

  /// 0..1 watched fraction, shown as a bar when set.
  final double? progress;

  /// When set (Continuar assistindo), the card shows an "x" that calls it.
  final VoidCallback? onRemove;

  @override
  ConsumerState<MovieCard> createState() => _MovieCardState();
}

/// Space kept at the end of the tag row while TMDB is on, so the rating chip
/// appearing never reflows the tags or changes the row height (no layout
/// jump).
const _ratingSlotWidth = 56.0, _ratingSlotHeight = 22.0;

class _MovieCardState extends ConsumerState<MovieCard> {
  bool _active = false;

  void _open() {
    final toDetails =
        widget.open == MovieOpen.details && ref.read(tmdbEnabledProvider);
    Navigator.of(context).push(
      toDetails
          ? MaterialPageRoute<void>(
              builder: (_) => MovieDetailsPage(movie: widget.movie),
            )
          : moviePlayerRoute(ref, widget.movie),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final t = parseMovieTitle(m.name);
    final tmdb = ref.watch(tmdbEnabledProvider);
    // Only a card that is built asks TMDB; lazy grids build visible ones.
    final info = tmdb
        ? ref.watch(tmdbMovieProvider(tmdbMovieQuery(m.name))).value
        : null;
    final poster = posterUrl(m.logo, info, TmdbImageSize.card);
    final reduce = MediaQuery.of(context).disableAnimations;
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _active = v),
      onShowHoverHighlight: (v) => setState(() => _active = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: _open,
        child: AnimatedScale(
          scale: _active && !reduce ? 1.03 : 1,
          duration: reduce ? Duration.zero : Tokens.hover,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _active ? Tokens.tileHi : Tokens.tile,
              borderRadius: BorderRadius.circular(Tokens.radius),
              border: Border.all(
                color: _active ? Tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (poster.isNotEmpty)
                  Opacity(
                    opacity: 0.35,
                    child: CachedThumb(
                      url: poster,
                      cacheWidth: 420,
                      fallback: const SizedBox.shrink(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          t.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: Tokens.display,
                            fontSize: 17,
                            height: 22 / 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (t.year != null)
                                  Text(
                                    '${t.year}',
                                    style: const TextStyle(
                                      color: Tokens.textDim,
                                      fontSize: 13,
                                    ),
                                  ),
                                for (final tag in t.tags) MovieTag(tag),
                              ],
                            ),
                          ),
                          if (tmdb)
                            SizedBox(
                              width: _ratingSlotWidth,
                              height: _ratingSlotHeight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: RatingChip(rating: info?.rating),
                              ),
                            ),
                        ],
                      ),
                      if (widget.progress != null) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: widget.progress,
                          minHeight: 3,
                          color: Tokens.accent,
                          backgroundColor: Tokens.line,
                        ),
                      ],
                    ],
                  ),
                ),
                CardActions(
                  type: m.type,
                  id: m.id,
                  show: _active,
                  onRemove: widget.onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
