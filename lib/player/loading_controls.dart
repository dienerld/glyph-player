import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../ui/theme.dart';
import 'player_startup.dart';

/// The desktop video controls with the [startup] state over the picture: a
/// spinner while connecting or buffering, the attempt number from the second
/// try, and an error with a retry button once every attempt failed. Passed as
/// `Video.controls`, so it also shows in fullscreen (a separate route that
/// rebuilds the controls). The controls' own spinner is turned off with
/// [noBufferingIndicator].
VideoControlsBuilder loadingVideoControls(PlayerStartup startup) =>
    (state) => Stack(
      fit: StackFit.expand,
      children: [
        MaterialDesktopVideoControls(state),
        ListenableBuilder(
          listenable: startup,
          builder: (context, _) => startup.failed
              ? _Failed(onRetry: startup.retry)
              : IgnorePointer(
                  child: startup.loading
                      ? _Connecting(attempt: startup.attempt)
                      : const SizedBox.shrink(),
                ),
        ),
      ],
    );

Widget noBufferingIndicator(BuildContext _) => const SizedBox.shrink();

class _Connecting extends StatelessWidget {
  const _Connecting({required this.attempt});
  final int attempt;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 40,
          child: CircularProgressIndicator(
            color: Tokens.accent,
            strokeWidth: 3,
            semanticsLabel: 'Carregando',
          ),
        ),
        if (attempt > 1) ...[
          const SizedBox(height: Tokens.gap),
          Text(
            'Tentando de novo: tentativa $attempt de ${PlayerStartup.attempts}',
            style: const TextStyle(color: Tokens.text),
          ),
        ],
      ],
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Tokens.panel,
        borderRadius: BorderRadius.circular(Tokens.radius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Tokens.error, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Não foi possível abrir',
            style: TextStyle(
              color: Tokens.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O servidor não respondeu depois de ${PlayerStartup.attempts} '
            'tentativas. Ele pode estar fora do ar ou instável.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tokens.textDim),
          ),
          const SizedBox(height: Tokens.gap),
          FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
        ],
      ),
    ),
  );
}
