import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// "Next episode in N s" prompt shown when an episode ends.
class AutoAdvanceOverlay extends StatefulWidget {
  const AutoAdvanceOverlay({
    super.key,
    required this.title,
    required this.onNow,
    required this.onCancel,
    this.seconds = 5,
  });
  final String title;
  final VoidCallback onNow, onCancel;
  final int seconds;

  @override
  State<AutoAdvanceOverlay> createState() => _AutoAdvanceOverlayState();
}

class _AutoAdvanceOverlayState extends State<AutoAdvanceOverlay> {
  late int _left = widget.seconds;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) {
        _finish(widget.onNow);
      } else {
        setState(() => _left--);
      }
    });
  }

  void _finish(VoidCallback action) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    action();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    right: 24,
    bottom: 96,
    child: Material(
      color: Tokens.panel,
      borderRadius: BorderRadius.circular(Tokens.radius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Próximo episódio em $_left s',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(widget.title, style: const TextStyle(color: Tokens.textDim)),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _finish(widget.onCancel),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _finish(widget.onNow),
                  child: const Text('Assistir agora'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
