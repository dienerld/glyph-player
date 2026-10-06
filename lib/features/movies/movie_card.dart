import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/movie_title.dart';
import '../../ui/theme.dart';
import '../shared/cached_thumb.dart';
import 'vod_player_page.dart';

/// Typographic card: most movies have no poster, so the title leads.
class MovieCard extends StatefulWidget {
  const MovieCard({super.key, required this.movie, this.progress});
  final Channel movie;

  /// 0..1 watched fraction, shown as a bar when set.
  final double? progress;

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _active = false;

  void _open() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => VodPlayerPage(queue: [widget.movie], index: 0),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final t = parseMovieTitle(m.name);
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
                color: _active ? Tokens.tally : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (m.logo.isNotEmpty)
                  Opacity(
                    opacity: 0.35,
                    child: CachedThumb(
                      url: m.logo,
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
                      Wrap(
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
                          for (final tag in t.tags) _Tag(tag),
                        ],
                      ),
                      if (widget.progress != null) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: widget.progress,
                          minHeight: 3,
                          color: Tokens.tally,
                          backgroundColor: Tokens.line,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: Tokens.line),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Tokens.textDim, fontSize: 11),
    ),
  );
}
