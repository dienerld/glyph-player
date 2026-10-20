import 'package:flutter/material.dart';

import '../../data/tmdb_info.dart';
import '../../ui/theme.dart';

/// `7.43` -> `7,4` (pt-BR decimal comma). Null when there is no vote to show.
String? ratingLabel(double? rating) {
  if (rating == null || rating <= 0) return null;
  return rating.toStringAsFixed(1).replaceAll('.', ',');
}

/// The poster to show: the list's own wins, TMDB's fills in when the list has
/// none. Empty when neither has one.
String posterUrl(String listPoster, TmdbInfo? info, TmdbImageSize size) {
  if (listPoster.isNotEmpty) return listPoster;
  final path = info?.posterPath;
  return path == null || path.isEmpty ? '' : tmdbImageUrl(path, size);
}

/// Small neutral chip with the TMDB vote ("7,4"). Renders nothing when
/// [rating] has no vote. Not the accent colour: purple stays for focus and
/// the primary action.
class RatingChip extends StatelessWidget {
  const RatingChip({super.key, required this.rating});
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final label = ratingLabel(rating);
    if (label == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Nota $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Tokens.ink.withValues(alpha: 0.7),
          border: Border.all(color: Tokens.line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 12, color: Tokens.textDim),
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(
                color: Tokens.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
