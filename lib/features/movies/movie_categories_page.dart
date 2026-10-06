import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../live/search_delegate.dart';
import '../settings/settings_page.dart';
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
                        itemBuilder: (_, i) => _CategoryTile(group: g[i]),
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

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({required this.group});
  final GroupCount group;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _active = false;

  /// Stable hue per category so the grid is scannable without artwork.
  Color get _tint {
    final hue = widget.group.name.codeUnits.fold<int>(7, (h, c) => h * 31 + c);
    return HSLColor.fromAHSL(
      1,
      (hue.abs() % 360).toDouble(),
      0.32,
      0.2,
    ).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovieGridPage(group: g.name)));
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _active = v),
      onShowHoverHighlight: (v) => setState(() => _active = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            open();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: open,
        child: AnimatedContainer(
          duration: Tokens.hover,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _tint,
            borderRadius: BorderRadius.circular(Tokens.radius),
            border: Border.all(
              color: _active ? Tokens.tally : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                categoryLabel(g.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: Tokens.display,
                  fontSize: 20,
                  height: 24 / 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${g.count} filmes',
                style: const TextStyle(color: Tokens.textDim, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
