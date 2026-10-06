import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Offered in the last minute of an episode: jump to the next one now.
class NextEpisodeBanner extends StatelessWidget {
  const NextEpisodeBanner({
    super.key,
    required this.title,
    required this.onSkip,
    required this.onDismiss,
  });
  final String title;
  final VoidCallback onSkip, onDismiss;

  @override
  Widget build(BuildContext context) => Positioned(
    right: 24,
    bottom: 96,
    child: Material(
      color: Tokens.panel,
      borderRadius: BorderRadius.circular(Tokens.radius),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A seguir',
                    style: TextStyle(color: Tokens.textDim, fontSize: 12),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: onSkip,
              child: const Text('Próximo episódio'),
            ),
            IconButton(
              tooltip: 'Dispensar',
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    ),
  );
}
