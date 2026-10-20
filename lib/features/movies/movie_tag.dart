import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Outlined chip with a title tag such as `4K` or `LEG`.
class MovieTag extends StatelessWidget {
  const MovieTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: Tokens.line),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Tokens.textDim, fontSize: 11),
    ),
  );
}
