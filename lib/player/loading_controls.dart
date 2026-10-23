import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../ui/theme.dart';
import 'player_connection.dart';

/// The desktop video controls with the [connection] state over the picture: a
/// spinner while connecting or buffering, the attempt number (from the second
/// try, or on every reconnect), and an error with a retry button once every
/// attempt failed. Passed as
/// `Video.controls`, so it also shows in fullscreen (a separate route that
/// rebuilds the controls). The controls' own spinner is turned off with
/// [noBufferingIndicator].
VideoControlsBuilder loadingVideoControls(PlayerConnection connection) =>
    (state) => Stack(
      fit: StackFit.expand,
      children: [
        MaterialDesktopVideoControls(state),
        ListenableBuilder(
          listenable: connection,
          builder: (context, _) => connection.failed
              ? _Failed(
                  reconnecting: connection.reconnecting,
                  onRetry: connection.retry,
                )
              : IgnorePointer(
                  child: connection.loading
                      ? _Connecting(
                          attempt: connection.attempt,
                          reconnecting: connection.reconnecting,
                        )
                      : const SizedBox.shrink(),
                ),
        ),
      ],
    );

Widget noBufferingIndicator(BuildContext _) => const SizedBox.shrink();

class _Connecting extends StatelessWidget {
  const _Connecting({required this.attempt, required this.reconnecting});
  final int attempt;
  final bool reconnecting;

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
        if (reconnecting || attempt > 1) ...[
          const SizedBox(height: Tokens.gap),
          Text(
            '${reconnecting ? 'Reconectando' : 'Tentando de novo'}: '
            'tentativa $attempt de ${PlayerConnection.attempts}',
            style: const TextStyle(color: Tokens.text),
          ),
        ],
      ],
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.reconnecting, required this.onRetry});
  final bool reconnecting;
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
          Text(
            reconnecting ? 'A transmissão caiu' : 'Não foi possível abrir',
            style: const TextStyle(
              color: Tokens.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${reconnecting ? 'Não voltou' : 'O servidor não respondeu'} '
            'depois de ${PlayerConnection.attempts} tentativas. Ele pode estar '
            'fora do ar ou instável.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Tokens.textDim),
          ),
          const SizedBox(height: Tokens.gap),
          FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
        ],
      ),
    ),
  );
}
