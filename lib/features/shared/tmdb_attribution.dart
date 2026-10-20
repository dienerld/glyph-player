import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Credit required by the TMDB API terms of use.
class TmdbAttribution extends StatelessWidget {
  const TmdbAttribution({super.key});

  @override
  Widget build(BuildContext context) => const Text(
    'This product uses the TMDB API but is not endorsed or certified by TMDB.',
    style: TextStyle(color: Tokens.textDim, fontSize: 12),
  );
}
