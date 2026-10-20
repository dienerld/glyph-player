import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Search box with debounce: [onChanged] fires ~300 ms after the last
/// keystroke, and at once when the field is cleared (x button or Esc).
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _ctrl = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {})); // x button visibility
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _timer?.cancel();
    if (text.isEmpty) {
      widget.onChanged('');
      return;
    }
    _timer = Timer(widget.debounce, () => widget.onChanged(text));
  }

  void _clear() {
    _timer?.cancel();
    _ctrl.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_ctrl.text.isNotEmpty) _clear();
        },
      },
      child: TextField(
        controller: _ctrl,
        onChanged: _typed,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: _clear,
                ),
        ),
      ),
    );
  }
}
