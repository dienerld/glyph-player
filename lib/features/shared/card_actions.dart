import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// The small round "x" that takes an item out of a Continue/Recents list.
class RemoveFromListButton extends StatelessWidget {
  const RemoveFromListButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: 'Remover da lista',
    iconSize: 18,
    visualDensity: VisualDensity.compact,
    icon: const Icon(Icons.close),
    onPressed: onPressed,
  );
}

/// Favorite toggle for a live channel or a movie. Hidden unless [show] (the
/// card is hovered/focused) or the item is already a favorite.
class FavoriteStar extends ConsumerStatefulWidget {
  const FavoriteStar({
    super.key,
    required this.type,
    required this.id,
    this.show = false,
  });
  final String type, id;
  final bool show;

  @override
  ConsumerState<FavoriteStar> createState() => _FavoriteStarState();
}

class _FavoriteStarState extends ConsumerState<FavoriteStar> {
  void _toggle(bool value) {
    ref.read(dbProvider).setFavorite(widget.type, widget.id, value);
    ref.invalidate(
      widget.type == 'movie' ? movieFavoritesProvider : favoritesProvider,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // A movie's details panel has its own star, on screen next to the card:
    // follow it.
    if (widget.type == 'movie') ref.watch(movieFavoritesProvider);
    final fav = ref.read(dbProvider).isFavorite(widget.type, widget.id);
    if (!fav && !widget.show) return const SizedBox.shrink();
    return IconButton.filledTonal(
      tooltip: fav ? 'Remover dos favoritos' : 'Favoritar',
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      icon: Icon(fav ? Icons.star : Icons.star_border),
      onPressed: () => _toggle(!fav),
    );
  }
}

/// Top-right overlay of a card: optional remove button plus the favorite star.
class CardActions extends StatelessWidget {
  const CardActions({
    super.key,
    required this.type,
    required this.id,
    required this.show,
    this.onRemove,
  });
  final String type, id;
  final bool show;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 4,
    right: 4,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onRemove != null) RemoveFromListButton(onPressed: onRemove!),
        FavoriteStar(type: type, id: id, show: show),
      ],
    ),
  );
}
