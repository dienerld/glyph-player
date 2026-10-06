import 'package:flutter/material.dart';
import 'features/shell/app_shell.dart';
import 'ui/theme.dart';

class GlyphApp extends StatelessWidget {
  const GlyphApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Glyph Player',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const AppShell(),
  );
}
