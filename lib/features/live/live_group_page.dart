import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../ui/theme.dart';
import 'channel_card.dart';

/// One live category's channels as a grid (the "Categorias" view).
class LiveGroupPage extends ConsumerWidget {
  const LiveGroupPage({super.key, required this.group});
  final String group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(groupChannelsProvider(group));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(group, style: Theme.of(context).textTheme.headlineMedium),
        toolbarHeight: 72,
      ),
      body: channels.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: Tokens.cardW,
            mainAxisExtent: Tokens.cardH + 12,
            crossAxisSpacing: Tokens.gap,
            mainAxisSpacing: Tokens.gap,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => ChannelCard(queue: list, index: i),
        ),
      ),
    );
  }
}
