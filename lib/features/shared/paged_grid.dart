import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import 'sort_menu.dart';

/// Lazy-loaded grid over a paged provider (movies or series): asks for the
/// next page near the end, jumps to the top when the sort order changes and
/// shows [emptyText] when there is nothing to list.
class PagedGrid<T> extends ConsumerStatefulWidget {
  const PagedGrid({
    super.key,
    required this.page,
    required this.loadMore,
    required this.sort,
    required this.delegate,
    required this.itemBuilder,
    this.emptyText,
  });

  final ProviderListenable<AsyncValue<Paged<T>>> page;
  final VoidCallback loadMore;
  final ProviderListenable<SortOrder> sort;
  final SliverGridDelegate delegate;
  final Widget Function(BuildContext, T) itemBuilder;
  final String? emptyText;

  @override
  ConsumerState<PagedGrid<T>> createState() => _PagedGridState<T>();
}

class _PagedGridState<T> extends ConsumerState<PagedGrid<T>> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final page = ref.read(widget.page).valueOrNull;
    if (page == null || page.loading || !page.hasMore) return;
    if (_scroll.position.extentAfter < loadMoreThreshold) widget.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    // A new sort order restarts the grid at page 1: go back to the top.
    ref.listen(widget.sort, (_, _) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
    // A page that does not fill the viewport never scrolls: check after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadMore();
    });
    return ref
        .watch(widget.page)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (page) {
            if (page.items.isEmpty && widget.emptyText != null) {
              return Center(
                child: Text(
                  widget.emptyText!,
                  style: const TextStyle(color: Tokens.textDim),
                ),
              );
            }
            return GridView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(24),
              gridDelegate: widget.delegate,
              itemCount: page.items.length + (page.loading ? 1 : 0),
              itemBuilder: (ctx, i) => i >= page.items.length
                  ? const LoadingCell()
                  : widget.itemBuilder(ctx, page.items[i]),
            );
          },
        );
  }
}

/// Text for an empty result list.
String noResultsText(String query) => 'Nenhum resultado para “${query.trim()}”';
