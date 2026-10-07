import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../shared/cached_thumb.dart';
import '../shared/card_actions.dart';
import '../shared/monogram.dart';
import 'series_page.dart';

const seriesCardWidth = 160.0;
const seriesCardHeight = 290.0;

String seasonsLabel(int n) => n == 1 ? '1 temporada' : '$n temporadas';

/// `Series | Netflix` -> `Netflix`; collections keep their own name and a
/// group with no name is labelled instead of rendering blank.
String distributorLabel(String group) {
  final label = group.replaceFirst(RegExp(r'^Series\s*\|\s*'), '').trim();
  return label.isEmpty ? 'Sem categoria' : label;
}

/// Poster card. When [removable], an "x" removes the series from Continue.
class SeriesCard extends ConsumerStatefulWidget {
  const SeriesCard({super.key, required this.summary, this.removable = false});
  final SeriesSummary summary;
  final bool removable;

  @override
  ConsumerState<SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends ConsumerState<SeriesCard> {
  bool _active = false;

  void _open() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SeriesPage(summary: widget.summary)),
  );

  void _remove() {
    ref
        .read(dbProvider)
        .hideSeries(widget.summary.group, widget.summary.name, DateTime.now());
    ref.invalidate(continueSeriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Tokens.tile,
                        borderRadius: BorderRadius.circular(Tokens.radius),
                        border: Border.all(
                          color: _active ? Tokens.tally : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Poster(url: s.poster, name: s.name),
                    ),
                    if (widget.removable)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: RemoveFromListButton(onPressed: _remove),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 18 / 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                seasonsLabel(s.seasons),
                style: const TextStyle(color: Tokens.textDim, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Remote poster with a monogram fallback (missing or broken image).
class Poster extends StatelessWidget {
  const Poster({super.key, required this.url, required this.name});
  final String url, name;

  @override
  Widget build(BuildContext context) {
    return CachedThumb(
      url: url,
      cacheWidth: 320,
      fallback: Center(child: Monogram(name: name, size: 40)),
    );
  }
}
