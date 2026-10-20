import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/tmdb_client.dart';
import '../../state/providers.dart';
import '../shared/tmdb_attribution.dart';
import '../../ui/theme.dart';
import '../shell/update_prompt.dart';

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
  final _tmdb = TextEditingController();
  bool _tmdbShown = false;
  bool _tmdbTesting = false;
  String? _tmdbMsg;
  bool _tmdbMsgOk = false;

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
    _tmdb.text = ref.read(tmdbKeyProvider);
    _tmdb.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _url.dispose();
    _tmdb.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(importControllerProvider.notifier)
        .refresh(newUrl: _url.text.trim());
  }

  void _saveTmdb() {
    ref.read(tmdbKeyProvider.notifier).set(_tmdb.text);
    final has = _tmdb.text.trim().isNotEmpty;
    setState(() {
      _tmdbMsgOk = true;
      _tmdbMsg = has
          ? 'Chave salva.'
          : 'Chave removida. Nada é enviado ao TMDB.';
    });
  }

  Future<void> _testTmdb() async {
    setState(() {
      _tmdbTesting = true;
      _tmdbMsg = null;
    });
    final r = await ref.read(tmdbKeyProvider.notifier).check(_tmdb.text);
    if (!mounted) return;
    setState(() {
      _tmdbTesting = false;
      _tmdbMsgOk = r == TmdbKeyStatus.ok;
      _tmdbMsg = switch (r) {
        TmdbKeyStatus.ok => 'Chave válida',
        TmdbKeyStatus.invalid => 'Chave inválida',
        TmdbKeyStatus.networkError => 'Sem conexão com o TMDB',
      };
    });
  }

  void _clearTmdbCache() {
    ref.read(tmdbKeyProvider.notifier).clearCache();
    setState(() {
      _tmdbMsgOk = true;
      _tmdbMsg = 'Cache de metadados limpo.';
    });
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
          child: SingleChildScrollView(
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
                const SizedBox(height: 24),
                Text(
                  'Atualizações',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(switch (ref.watch(availableUpdateProvider)) {
                        AsyncLoading() => 'Verificando…',
                        AsyncData(value: final u?) =>
                          'Versão ${u.version} disponível',
                        _ =>
                          'Versão ${ref.watch(appVersionProvider).value ?? ''} · você está na mais recente',
                      }, style: const TextStyle(color: Tokens.textDim)),
                    ),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(availableUpdateProvider),
                      child: const Text('Verificar agora'),
                    ),
                  ],
                ),
                const UpdatePrompt(dismissible: false),
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
                const SizedBox(height: 32),
                Text(
                  'Metadados (TMDB)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Com uma chave, os títulos dos filmes e séries que você '
                  'navega são enviados ao TMDB para buscar pôster, nota e '
                  'sinopse. Sem chave, nada é enviado. Para obter uma, crie '
                  'uma conta gratuita em themoviedb.org e gere uma chave de '
                  'API.',
                  style: TextStyle(color: Tokens.textDim),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tmdb,
                  obscureText: !_tmdbShown,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Chave da API do TMDB',
                    suffixIcon: IconButton(
                      tooltip: _tmdbShown ? 'Ocultar chave' : 'Mostrar chave',
                      icon: Icon(
                        _tmdbShown ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _tmdbShown = !_tmdbShown),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: _saveTmdb,
                      child: const Text('Salvar chave'),
                    ),
                    OutlinedButton(
                      onPressed: _tmdb.text.trim().isEmpty || _tmdbTesting
                          ? null
                          : _testTmdb,
                      child: const Text('Testar chave'),
                    ),
                    if (_tmdbTesting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    OutlinedButton(
                      onPressed: _clearTmdbCache,
                      child: const Text('Limpar cache de metadados'),
                    ),
                  ],
                ),
                if (_tmdbMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _tmdbMsg!,
                    style: TextStyle(
                      color: _tmdbMsgOk
                          ? Tokens.textDim
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const TmdbAttribution(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
