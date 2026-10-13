import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/updater.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';

/// "New version available" strip with the update action; empty when the app is
/// up to date. In the shell it can be dismissed until the next launch.
class UpdatePrompt extends ConsumerStatefulWidget {
  const UpdatePrompt({super.key, required this.dismissible});
  final bool dismissible;

  @override
  ConsumerState<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends ConsumerState<UpdatePrompt> {
  bool _hidden = false, _busy = false;
  String? _error;

  Future<void> _install(UpdateInfo u) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await installUpdate(u);
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível atualizar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(availableUpdateProvider).value;
    if (u == null || (widget.dismissible && _hidden)) {
      return const SizedBox.shrink();
    }
    final opensPage = updateMode(u) == UpdateMode.openPage;
    return Container(
      width: double.infinity,
      color: Tokens.accentDim,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            _busy
                ? 'Baixando a versão ${u.version}…'
                : _error ?? 'Nova versão ${u.version} disponível',
          ),
          if (_busy)
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 2),
            )
          else ...[
            FilledButton(
              onPressed: () => _install(u),
              child: Text(opensPage ? 'Baixar' : 'Atualizar e reiniciar'),
            ),
            if (widget.dismissible)
              TextButton(
                onPressed: () => setState(() => _hidden = true),
                child: const Text('Depois'),
              ),
          ],
        ],
      ),
    );
  }
}
