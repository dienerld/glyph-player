import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../settings/settings_page.dart';
import '../shared/search_field.dart';
import '../shared/section_tile.dart';
import '../shared/sort_menu.dart';
import 'series_card.dart';
import 'series_grid_page.dart';

class SeriesHomePage extends ConsumerStatefulWidget {
  const SeriesHomePage({super.key});

  @override
  ConsumerState<SeriesHomePage> createState() => _SeriesHomePageState();
}

class _SeriesHomePageState extends ConsumerState<SeriesHomePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scope = GridScope.search(_query);
    final sections = ref.watch(seriesSectionsProvider);
    final cont = ref.watch(continueSeriesProvider).value ?? const [];
    final favs = ref.watch(seriesFavoritesProvider).value ?? const [];
    final db = ref.watch(dbProvider);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
            child: Row(
              children: [
                Text(
                  'Séries',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: SearchField(
                    hint: 'Buscar séries',
                    onChanged: (q) => setState(() => _query = q),
                  ),
                ),
                if (scope.searching)
                  SortMenu(
                    value: ref.watch(seriesSortProvider),
                    onSelected: ref.read(seriesSortProvider.notifier).set,
                  ),
              ],
            ),
          ),
          Expanded(
            child: scope.searching
                ? SeriesResults(scope: scope, query: _query)
                : sections.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Center(child: Text('Erro: $e')),
                    data: (g) {
                      if (g.isEmpty) return const _EmptySeries();
                      return CustomScrollView(
                        slivers: [
                          if (cont.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _SeriesRow(
                                title: 'Continuar assistindo',
                                items: cont,
                                removable: true,
                              ),
                            ),
                          if (favs.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _SeriesRow(
                                title: 'Favoritos',
                                items: favs,
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
                              itemBuilder: (_, i) {
                                final n = db.seriesCount(g[i].name);
                                return SectionTile(
                                  label: distributorLabel(g[i].name),
                                  countText: n == 1 ? '1 série' : '$n séries',
                                  tintKey: g[i].name,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SeriesGridPage(group: g[i].name),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    required this.title,
    required this.items,
    this.removable = false,
  });
  final String title;
  final List<SeriesSummary> items;
  final bool removable;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      SizedBox(
        height: seriesCardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: Tokens.gap),
          itemBuilder: (_, i) => SizedBox(
            width: seriesCardWidth,
            child: SeriesCard(summary: items[i], removable: removable),
          ),
        ),
      ),
    ],
  );
}

class _EmptySeries extends StatelessWidget {
  const _EmptySeries();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.tv_outlined, size: 48, color: Tokens.textDim),
        const SizedBox(height: 16),
        Text(
          'Nenhuma série ainda',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Atualize a lista em Configurações para carregar as séries.',
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
