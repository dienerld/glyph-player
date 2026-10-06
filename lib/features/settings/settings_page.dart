import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';

void openSettings(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => const SettingsPage()));

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _url = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref
        .read(playlistUrlStoreProvider)
        .read()
        .then((v) {
          if (mounted && v != null) _url.text = v;
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(importControllerProvider.notifier)
        .refresh(newUrl: _url.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(importControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _url,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'URL da lista (M3U_plus)',
                    helperText: 'Guardada no cofre seguro do sistema.',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: s is ImportRunning ? null : _save,
                  child: const Text('Salvar e atualizar'),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar conteúdo adulto'),
                  subtitle: const Text(
                    'Oculto por padrão em Ao vivo, Filmes e na busca.',
                    style: TextStyle(color: Tokens.textDim),
                  ),
                  value: ref.watch(showAdultProvider),
                  onChanged: (v) => ref.read(showAdultProvider.notifier).set(v),
                ),
                const SizedBox(height: 16),
                switch (s) {
                  ImportRunning(:final downloading, :final count) => Text(
                    downloading ? 'Baixando…' : 'Importando… $count itens',
                    style: const TextStyle(color: Tokens.textDim),
                  ),
                  ImportFailed(:final message) => Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  ImportIdle() => const SizedBox.shrink(),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
