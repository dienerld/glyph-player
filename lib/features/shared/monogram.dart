import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// First letters of a name, used where there is no logo or poster.
class Monogram extends StatelessWidget {
  const Monogram({super.key, required this.name, this.size = 28});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    return Text(
      letters,
      style: TextStyle(
        fontFamily: Tokens.display,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: Tokens.textDim,
      ),
    );
  }
}
