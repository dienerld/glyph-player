import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import 'channel_card.dart';

class ChannelSearchDelegate extends SearchDelegate<void> {
  ChannelSearchDelegate() : super(searchFieldLabel: 'Buscar canal');

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
      );

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Limpar',
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        tooltip: 'Voltar',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildSuggestions(BuildContext context) => _results();
  @override
  Widget buildResults(BuildContext context) => _results();

  Widget _results() => Consumer(builder: (context, ref, _) {
        final r = ref.watch(searchProvider(query));
        return r.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (list) => list.isEmpty
              ? Center(
                  child: Text(
                    query.trim().isEmpty ? 'Digite para buscar' : 'Nada encontrado',
                    style: const TextStyle(color: Tokens.textDim),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisExtent: Tokens.cardH + 12,
                    crossAxisSpacing: Tokens.gap,
                    mainAxisSpacing: Tokens.gap,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => ChannelCard(queue: list, index: i),
                ),
        );
      });
}
