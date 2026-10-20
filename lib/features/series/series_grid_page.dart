import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../shared/paged_grid.dart';
import '../shared/search_field.dart';
import '../shared/sort_menu.dart';
import 'series_card.dart';

const seriesGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 190,
  mainAxisExtent: seriesCardHeight,
  crossAxisSpacing: Tokens.gap,
  mainAxisSpacing: Tokens.gap,
);

/// Series of [scope] in a lazy grid, with the "no results" message when the
/// scope is a search.
class SeriesResults extends ConsumerWidget {
  const SeriesResults({super.key, required this.scope, required this.query});
  final GridScope scope;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PagedGrid<SeriesSummary>(
    page: seriesPageProvider(scope),
    loadMore: () => ref.read(seriesPageProvider(scope).notifier).loadMore(),
    sort: seriesSortProvider,
    delegate: seriesGridDelegate,
    itemBuilder: (_, s) => SeriesCard(summary: s),
    emptyText: scope.searching ? noResultsText(query) : null,
  );
}

class SeriesGridPage extends ConsumerStatefulWidget {
  const SeriesGridPage({super.key, required this.group});
  final String group;

  @override
  ConsumerState<SeriesGridPage> createState() => _SeriesGridPageState();
}

class _SeriesGridPageState extends ConsumerState<SeriesGridPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scope = GridScope.search(_query, group: widget.group);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          distributorLabel(widget.group),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          SizedBox(
            width: 260,
            child: SearchField(
              hint: 'Buscar nesta categoria',
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          SortMenu(
            value: ref.watch(seriesSortProvider),
            onSelected: ref.read(seriesSortProvider.notifier).set,
          ),
          const SizedBox(width: 12),
        ],
        toolbarHeight: 72,
      ),
      body: SeriesResults(scope: scope, query: _query),
    );
  }
}
