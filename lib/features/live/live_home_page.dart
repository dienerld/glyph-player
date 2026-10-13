import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../settings/settings_page.dart';
import '../shared/section_tile.dart';
import 'category_row.dart';
import 'live_group_page.dart';
import 'search_delegate.dart';

class LiveHomePage extends ConsumerWidget {
  const LiveHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(liveGroupsProvider);
    final recents = ref.watch(recentsProvider).value ?? const [];
    final favorites = ref.watch(favoritesProvider).value ?? const [];
    final view = ref.watch(liveViewProvider);
    final importing = ref.watch(importControllerProvider) is ImportRunning;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
            child: Row(
              children: [
                Text(
                  'Ao vivo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                SegmentedButton<LiveView>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: LiveView.rows,
                      icon: Icon(Icons.view_agenda_outlined),
                      label: Text('Linhas'),
                    ),
                    ButtonSegment(
                      value: LiveView.categories,
                      icon: Icon(Icons.grid_view),
                      label: Text('Categorias'),
                    ),
                  ],
                  selected: {view},
                  onSelectionChanged: (s) =>
                      ref.read(liveViewProvider.notifier).set(s.first),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.search),
                  onPressed: () => showSearch(
                    context: context,
                    delegate: ChannelSearchDelegate(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 2,
            child: importing
                ? const LinearProgressIndicator(minHeight: 2)
                : null,
          ),
          Expanded(
            child: groups.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (g) {
                if (g.isEmpty) return const _EmptyState();
                if (view == LiveView.categories) return _Categories(g);
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: g.length + 2,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return recents.isEmpty
                          ? const SizedBox.shrink()
                          : CategoryRow(
                              title: 'Recentes',
                              channels: recents,
                              wide: true,
                              onRemove: (c) {
                                ref.read(dbProvider).removeRecent(c.type, c.id);
                                ref.invalidate(recentsProvider);
                              },
                            );
                    }
                    if (i == 1) {
                      return favorites.isEmpty
                          ? const SizedBox.shrink()
                          : CategoryRow(
                              title: 'Favoritos',
                              channels: favorites,
                            );
                    }
                    final group = g[i - 2].name;
                    final ch =
                        ref.watch(groupChannelsProvider(group)).value ??
                        const [];
                    return CategoryRow(title: group, channels: ch);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories(this.groups);
  final List<GroupCount> groups;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(24),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 240,
      mainAxisExtent: 104,
      crossAxisSpacing: Tokens.gap,
      mainAxisSpacing: Tokens.gap,
    ),
    itemCount: groups.length,
    itemBuilder: (_, i) => SectionTile(
      label: groups[i].name,
      countText: '${groups[i].count} canais',
      tintKey: groups[i].name,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveGroupPage(group: groups[i].name)),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.live_tv, size: 48, color: Tokens.textDim),
        const SizedBox(height: 16),
        Text(
          'Nenhum canal ainda',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Adicione a URL da sua lista e atualize.',
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
