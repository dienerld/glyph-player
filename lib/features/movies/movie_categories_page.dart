import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../live/search_delegate.dart';
import '../settings/settings_page.dart';
import '../shared/section_tile.dart';
import 'movie_card.dart';
import 'movie_grid_page.dart';

/// `Filmes | Drama` -> `Drama`.
String categoryLabel(String group) =>
    group.replaceFirst(RegExp(r'^Filmes\s*\|\s*'), '');

class MovieCategoriesPage extends ConsumerWidget {
  const MovieCategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(movieGroupsProvider);
    final cont = ref.watch(continueWatchingProvider).value ?? const [];
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
                IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.search),
                  onPressed: () => showSearch(
                    context: context,
                    delegate: ChannelSearchDelegate(type: 'movie'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: groups.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (g) {
                if (g.isEmpty) return const _EmptyMovies();
                return CustomScrollView(
                  slivers: [
                    if (cont.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _ContinueRow(items: cont, db: db),
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
                              builder: (_) => MovieGridPage(group: g[i].name),
                            ),
                          ),
                        ),
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

class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.items, required this.db});
  final List<Channel> items;
  final Db db;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Text(
          'Continuar assistindo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: Tokens.gap),
          itemBuilder: (_, i) {
            final p = db.progressOf(items[i].type, items[i].id);
            final frac = p == null || p.durationMs <= 0
                ? null
                : (p.positionMs / p.durationMs).clamp(0.0, 1.0);
            return SizedBox(
              width: 210,
              child: MovieCard(movie: items[i], progress: frac),
            );
          },
        ),
      ),
    ],
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
