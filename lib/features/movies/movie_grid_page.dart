import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../ui/theme.dart';
import 'movie_card.dart';
import 'movie_categories_page.dart';

class MovieGridPage extends ConsumerWidget {
  const MovieGridPage({super.key, required this.group});
  final String group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesInProvider(group));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          categoryLabel(group),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        toolbarHeight: 72,
      ),
      body: movies.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisExtent: 128,
            crossAxisSpacing: Tokens.gap,
            mainAxisSpacing: Tokens.gap,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => MovieCard(movie: list[i]),
        ),
      ),
    );
  }
}
