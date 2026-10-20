import 'package:flutter/material.dart';

import '../../data/database.dart';

const _labels = {
  SortOrder.recent: 'Adicionados recentes',
  SortOrder.az: 'A → Z',
  SortOrder.za: 'Z → A',
};

/// AppBar action that picks the sort order of a category grid.
class SortMenu extends StatelessWidget {
  const SortMenu({super.key, required this.value, required this.onSelected});
  final SortOrder value;
  final ValueChanged<SortOrder> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortOrder>(
      tooltip: 'Ordenar',
      icon: const Icon(Icons.sort),
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final o in SortOrder.values)
          CheckedPopupMenuItem<SortOrder>(
            value: o,
            checked: o == value,
            child: Text(_labels[o]!),
          ),
      ],
    );
  }
}

/// Distance from the end of a grid at which the next page is requested.
const loadMoreThreshold = 600.0;

/// Small spinner cell shown at the end of a grid while a page loads.
class LoadingCell extends StatelessWidget {
  const LoadingCell({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}
