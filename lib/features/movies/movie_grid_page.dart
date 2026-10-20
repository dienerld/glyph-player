import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../shared/paged_grid.dart';
import '../shared/search_field.dart';
import '../shared/sort_menu.dart';
import 'movie_card.dart';
import 'movie_categories_page.dart';
import 'movie_details_panel.dart';

const movieGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 210,
  mainAxisExtent: 128,
  crossAxisSpacing: Tokens.gap,
  mainAxisSpacing: Tokens.gap,
);

/// Movies of [scope] in a lazy grid, with the "no results" message when the
/// scope is a search. With a TMDB key a card opens its details in the grid,
/// below its row.
class MovieResults extends ConsumerWidget {
  const MovieResults({super.key, required this.scope, required this.query});
  final GridScope scope;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PagedGrid<Channel>(
    page: moviesPageProvider(scope),
    loadMore: () => ref.read(moviesPageProvider(scope).notifier).loadMore(),
    sort: movieSortProvider,
    delegate: movieGridDelegate,
    itemBuilder: (_, m) => MovieCard(movie: m),
    emptyText: scope.searching ? noResultsText(query) : null,
    panel: movieGridPanel,
  );
}

class MovieGridPage extends ConsumerStatefulWidget {
  const MovieGridPage({super.key, required this.group});
  final String group;

  @override
  ConsumerState<MovieGridPage> createState() => _MovieGridPageState();
}

class _MovieGridPageState extends ConsumerState<MovieGridPage> {
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
          categoryLabel(widget.group),
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
            value: ref.watch(movieSortProvider),
            onSelected: ref.read(movieSortProvider.notifier).set,
          ),
          const SizedBox(width: 12),
        ],
        toolbarHeight: 72,
      ),
      body: MovieResults(scope: scope, query: _query),
    );
  }
}
