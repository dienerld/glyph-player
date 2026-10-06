import 'package:flutter/material.dart';

/// Design tokens from docs/design/DIRECTION.md.
class Tokens {
  static const ink = Color(0xFF0B0E14);
  static const panel = Color(0xFF131822);
  static const tile = Color(0xFF1A2030);
  static const tileHi = Color(0xFF222A3E);
  static const line = Color(0xFF2A3348);
  static const text = Color(0xFFE8ECF4);
  static const textDim = Color(0xFF98A3BB);
  static const tally = Color(0xFFFF5B3A);
  static const tallyDim = Color(0x2EFF5B3A);

  static const radius = 14.0;
  static const gap = 16.0;
  static const railWidth = 72.0;
  static const cardW = 168.0, cardH = 112.0;
  static const wideW = 240.0, wideH = 135.0;
  static const hover = Duration(milliseconds: 120);
  static const slide = Duration(milliseconds: 220);
  static const slideCurve = Cubic(0.16, 1, 0.3, 1);

  static const display = 'Bricolage Grotesque';
  static const ui = 'Instrument Sans';
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Tokens.tally,
    onPrimary: Tokens.ink,
    surface: Tokens.panel,
    onSurface: Tokens.text,
    onSurfaceVariant: Tokens.textDim,
    outline: Tokens.line,
    error: Color(0xFFFF8A75),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tokens.ink,
    fontFamily: Tokens.ui,
    splashFactory: NoSplash.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Tokens.text, displayColor: Tokens.text).copyWith(
          titleLarge: const TextStyle(
            fontFamily: Tokens.display,
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          headlineMedium: const TextStyle(
            fontFamily: Tokens.display,
            fontSize: 28,
            height: 32 / 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Tokens.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Tokens.line),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Tokens.tally, width: 2)),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Tokens.tally,
      selectionColor: Tokens.tallyDim,
    ),
  );
}
