import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import 'item_expansion.dart';
import 'sort_menu.dart';

/// Lazy-loaded grid over a paged provider (movies or series): asks for the
/// next page near the end, jumps to the top when the sort order changes and
/// shows [emptyText] when there is nothing to list.
///
/// With [panel] it is also an accordion: an item can open a full-width details
/// panel right below its row, pushing the rows after it down. Only one is
/// open; sorting or a new search closes it.
class PagedGrid<T> extends ConsumerStatefulWidget {
  const PagedGrid({
    super.key,
    required this.page,
    required this.loadMore,
    required this.sort,
    required this.delegate,
    required this.itemBuilder,
    this.emptyText,
    this.panel,
  });

  final ProviderListenable<AsyncValue<Paged<T>>> page;
  final VoidCallback loadMore;
  final ProviderListenable<SortOrder> sort;

  /// Cell size and spacing. With [panel] it has to lay out regular tiles (as
  /// [SliverGridDelegateWithMaxCrossAxisExtent] does).
  final SliverGridDelegate delegate;
  final Widget Function(BuildContext, T) itemBuilder;
  final String? emptyText;

  /// Opt-in details accordion; see [ExpandableItem] for how a card opens it.
  final ItemPanel<T>? panel;

  @override
  ConsumerState<PagedGrid<T>> createState() => _PagedGridState<T>();
}

const _padding = 24.0;

class _PagedGridState<T> extends ConsumerState<PagedGrid<T>> {
  final _scroll = ScrollController();
  final _expansion = ItemExpansion();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _expansion.addListener(_changed);
  }

  @override
  void didUpdateWidget(PagedGrid<T> old) {
    super.didUpdateWidget(old);
    // Another search or category: a different list, the panel goes.
    if (old.page != widget.page) _expansion.reset();
  }

  @override
  void dispose() {
    _expansion.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
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
      _expansion.reset();
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
            final panel = widget.panel;
            if (panel != null) return _rows(page, panel);
            return GridView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(_padding),
              gridDelegate: widget.delegate,
              itemCount: page.items.length + (page.loading ? 1 : 0),
              itemBuilder: (ctx, i) => i >= page.items.length
                  ? const LoadingCell()
                  : widget.itemBuilder(ctx, page.items[i]),
            );
          },
        );
  }

  /// The grid as a list of rows, so a panel can sit between two of them at
  /// full width. Same cells as [GridView]: the column count and sizes come
  /// from the delegate for the current width.
  Widget _rows(Paged<T> page, ItemPanel<T> panel) => LayoutBuilder(
    builder: (context, box) {
      final tiles = _tileLayout(box.maxWidth - 2 * _padding);
      final cols = tiles.crossAxisCount;
      final items = page.items;
      final cells = items.length + (page.loading ? 1 : 0);
      final rowCount = (cells / cols).ceil();

      // Where each panel goes: right after the row of its item.
      final at = <Object, int>{};
      final wanted = _expansion.shown.toSet();
      if (wanted.isNotEmpty) {
        for (var i = 0; i < items.length && at.length < wanted.length; i++) {
          final k = panel.keyOf(items[i]);
          if (wanted.contains(k)) at[k] = i;
        }
      }
      _expansion.retainWhere(at.containsKey);
      final panels = [for (final k in _expansion.shown) (key: k, index: at[k]!)]
        ..sort((a, b) => a.index.compareTo(b.index));

      // Entries: a row number (int) or a panel.
      final entries = <Object>[];
      final entryOfPanel = <Object, int>{};
      var p = 0;
      for (var r = 0; r < rowCount; r++) {
        entries.add(r);
        while (p < panels.length && panels[p].index ~/ cols == r) {
          entryOfPanel[panels[p].key] = entries.length;
          entries.add(panels[p]);
          p++;
        }
      }

      final maxHeight = panelMaxHeight(box.maxHeight);
      final open = _expansion.open;

      Widget row(BuildContext ctx, int r) {
        final children = <Widget>[];
        for (var c = 0; c < cols; c++) {
          final i = r * cols + c;
          if (c > 0) {
            children.add(
              SizedBox(
                width: tiles.crossAxisStride - tiles.childCrossAxisExtent,
              ),
            );
          }
          final Widget cell;
          if (i < items.length) {
            final k = panel.keyOf(items[i]);
            cell = ExpandableItem(
              expansion: _expansion,
              itemKey: k,
              isOpen: k == open,
              child: widget.itemBuilder(ctx, items[i]),
            );
          } else if (i < cells) {
            cell = const LoadingCell();
          } else {
            cell = const SizedBox.shrink();
          }
          children.add(
            SizedBox(
              width: tiles.childCrossAxisExtent,
              height: tiles.childMainAxisExtent,
              child: cell,
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(
            top: r == 0 ? 0 : tiles.mainAxisStride - tiles.childMainAxisExtent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
      }

      Widget panelSlot(BuildContext ctx, ({Object key, int index}) e) =>
          ExpandingPanel(
            key: ValueKey(_PanelId(e.key)),
            open: e.key == open,
            gap: tiles.mainAxisStride - tiles.childMainAxisExtent,
            onClosed: () => _expansion.closed(e.key),
            child: panel.builder(
              ctx,
              items[e.index],
              maxHeight,
              () => _expansion.close(returnFocus: true),
            ),
          );

      return CloseOnEscape(
        expansion: _expansion,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(_padding),
              sliver: SliverList.builder(
                itemCount: entries.length,
                // A panel keeps its state (animation, focus) when the rows
                // reflow, e.g. the window got narrower.
                findChildIndexCallback: (key) => key is ValueKey<_PanelId>
                    ? entryOfPanel[key.value.itemKey]
                    : null,
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  return e is int
                      ? row(ctx, e)
                      : panelSlot(ctx, e as ({Object key, int index}));
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  /// What [PagedGrid.delegate] lays out for a grid [width] wide.
  SliverGridRegularTileLayout _tileLayout(double width) {
    final w = width < 0 ? 0.0 : width;
    final layout = widget.delegate.getLayout(
      SliverConstraints(
        axisDirection: AxisDirection.down,
        growthDirection: GrowthDirection.forward,
        userScrollDirection: ScrollDirection.idle,
        scrollOffset: 0,
        precedingScrollExtent: 0,
        overlap: 0,
        remainingPaintExtent: 0,
        crossAxisExtent: w,
        crossAxisDirection: AxisDirection.right,
        viewportMainAxisExtent: 0,
        remainingCacheExtent: 0,
        cacheOrigin: 0,
      ),
    );
    return layout as SliverGridRegularTileLayout;
  }
}

/// Key of a panel entry, distinct from any other key in the list.
@immutable
class _PanelId {
  const _PanelId(this.itemKey);
  final Object itemKey;

  @override
  bool operator ==(Object other) =>
      other is _PanelId && other.itemKey == itemKey;

  @override
  int get hashCode => itemKey.hashCode;
}

/// Text for an empty result list.
String noResultsText(String query) => 'Nenhum resultado para “${query.trim()}”';
