import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../ui/theme.dart';
import 'series_card.dart';

class SeriesGridPage extends ConsumerWidget {
  const SeriesGridPage({super.key, required this.group});
  final String group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesInProvider(group));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          distributorLabel(group),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        toolbarHeight: 72,
      ),
      body: series.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            mainAxisExtent: seriesCardHeight,
            crossAxisSpacing: Tokens.gap,
            mainAxisSpacing: Tokens.gap,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => SeriesCard(summary: list[i]),
        ),
      ),
    );
  }
}
