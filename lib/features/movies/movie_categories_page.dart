import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../settings/settings_page.dart';
import '../shared/item_expansion.dart';
import '../shared/search_field.dart';
import '../shared/section_tile.dart';
import '../shared/sort_menu.dart';
import 'movie_card.dart';
import 'movie_details_panel.dart';
import 'movie_grid_page.dart';

/// `Filmes | Drama` -> `Drama`.
String categoryLabel(String group) {
  final label = group.replaceFirst(RegExp(r'^Filmes\s*\|\s*'), '').trim();
  return label.isEmpty ? 'Sem categoria' : label;
}

class MovieCategoriesPage extends ConsumerStatefulWidget {
  const MovieCategoriesPage({super.key});

  @override
  ConsumerState<MovieCategoriesPage> createState() =>
      _MovieCategoriesPageState();
}

class _MovieCategoriesPageState extends ConsumerState<MovieCategoriesPage> {
  String _query = '';

  /// The details panel of a Favoritos card, below that row.
  final _favPanel = ItemExpansion();

  @override
  void initState() {
    super.initState();
    _favPanel.addListener(_changed);
  }

  @override
  void dispose() {
    _favPanel.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scope = GridScope.search(_query);
    final groups = ref.watch(movieGroupsProvider);
    final cont = ref.watch(continueWatchingProvider).value ?? const [];
    final favs = ref.watch(movieFavoritesProvider).value ?? const [];
    final db = ref.watch(dbProvider);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
            child: Row(
              children: [
                Text(
                  'Filmes',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: SearchField(
                    hint: 'Buscar filmes',
                    onChanged: (q) {
                      _favPanel.reset();
                      setState(() => _query = q);
                    },
                  ),
                ),
                if (scope.searching)
                  SortMenu(
                    value: ref.watch(movieSortProvider),
                    onSelected: ref.read(movieSortProvider.notifier).set,
                  ),
              ],
            ),
          ),
          Expanded(
            child: scope.searching
                ? MovieResults(scope: scope, query: _query)
                : groups.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Center(child: Text('Erro: $e')),
                    data: (g) {
                      if (g.isEmpty) return const _EmptyMovies();
                      // A favorite taken out of the list loses its panel.
                      final favIds = {for (final f in favs) movieKey(f)};
                      _favPanel.retainWhere(favIds.contains);
                      return LayoutBuilder(
                        builder: (context, box) => CloseOnEscape(
                          expansion: _favPanel,
                          child: CustomScrollView(
                            slivers: [
                              if (cont.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _MovieRow(
                                    title: 'Continuar assistindo',
                                    items: cont,
                                    db: db,
                                    open: MovieOpen.player, // resuming
                                    withProgress: true,
                                    onRemove: (m) {
                                      db.hideContinue(
                                        m.type,
                                        m.id,
                                        DateTime.now(),
                                      );
                                      ref.invalidate(continueWatchingProvider);
                                    },
                                  ),
                                ),
                              if (favs.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _MovieRow(
                                    title: 'Favoritos',
                                    items: favs,
                                    db: db,
                                    expansion: _favPanel,
                                  ),
                                ),
                              if (favs.isNotEmpty && _favPanel.shown.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: _FavoritePanels(
                                    expansion: _favPanel,
                                    favs: favs,
                                    maxHeight: panelMaxHeight(box.maxHeight),
                                  ),
                                ),
                              SliverPadding(
                                padding: const EdgeInsets.all(24),
                                sliver: SliverGrid.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 240,
                                        mainAxisExtent: 104,
                                        crossAxisSpacing: Tokens.gap,
                                        mainAxisSpacing: Tokens.gap,
                                      ),
                                  itemCount: g.length,
                                  itemBuilder: (_, i) => SectionTile(
                                    label: categoryLabel(g[i].name),
                                    countText: '${g[i].count} filmes',
                                    tintKey: g[i].name,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MovieGridPage(group: g[i].name),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MovieRow extends StatelessWidget {
  const _MovieRow({
    required this.title,
    required this.items,
    required this.db,
    this.open = MovieOpen.details,
    this.withProgress = false,
    this.onRemove,
    this.expansion,
  });
  final String title;
  final List<Channel> items;
  final Db db;
  final MovieOpen open;
  final bool withProgress;
  final void Function(Channel)? onRemove;

  /// When set, a card opens its details panel below this row.
  final ItemExpansion? expansion;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: Tokens.gap),
          itemBuilder: (_, i) {
            final p = withProgress
                ? db.progressOf(items[i].type, items[i].id)
                : null;
            final frac = p == null || p.durationMs <= 0
                ? null
                : (p.positionMs / p.durationMs).clamp(0.0, 1.0);
            final Widget card = MovieCard(
              movie: items[i],
              open: open,
              progress: frac,
              onRemove: onRemove == null ? null : () => onRemove!(items[i]),
            );
            final e = expansion;
            final key = movieKey(items[i]);
            return SizedBox(
              width: 210,
              child: e == null
                  ? card
                  : ExpandableItem(
                      expansion: e,
                      itemKey: key,
                      isOpen: e.open == key,
                      child: card,
                    ),
            );
          },
        ),
      ),
    ],
  );
}

/// The details panel of a Favoritos card (and, while it shrinks, the one it
/// replaced), right below that row.
class _FavoritePanels extends StatelessWidget {
  const _FavoritePanels({
    required this.expansion,
    required this.favs,
    required this.maxHeight,
  });
  final ItemExpansion expansion;
  final List<Channel> favs;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      children: [
        for (final k in expansion.shown)
          ExpandingPanel(
            key: ValueKey(k),
            open: k == expansion.open,
            onClosed: () => expansion.closed(k),
            child: MovieDetailsPanel(
              movie: favs.firstWhere((f) => movieKey(f) == k),
              maxHeight: maxHeight,
              onClose: () => expansion.close(returnFocus: true),
            ),
          ),
      ],
    ),
  );
}

class _EmptyMovies extends StatelessWidget {
  const _EmptyMovies();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.movie_outlined, size: 48, color: Tokens.textDim),
        const SizedBox(height: 16),
        Text(
          'Nenhum filme ainda',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Atualize a lista em Configurações para carregar os filmes.',
          style: TextStyle(color: Tokens.textDim),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => openSettings(context),
          child: const Text('Configurações'),
        ),
      ],
    ),
  );
}
