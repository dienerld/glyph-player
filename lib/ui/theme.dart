import 'package:flutter/material.dart';

/// Design tokens, from the Glyph design system (docs/design/DIRECTION.md).
/// Neutrals carry a trace of purple; purple is the single saturated accent.
class Tokens {
  static const ink = Color(0xFF17131C); // neutral-900: app background
  static const panel = Color(0xFF241F2B); // neutral-800: rail, panels, cards
  static const tile = Color(0xFF241F2B); // neutral-800
  static const tileHi = Color(0xFF453F4E); // neutral-700: hover
  static const line = Color(0xFF453F4E); // neutral-700: hairlines, bar tracks
  static const text = Color(0xFFDDD8E0); // neutral-200
  static const textStrong = Color(0xFFFFFFFF); // titles
  static const textDim = Color(0xFFA79FB0); // neutral-400 (6.3:1 on ink)
  static const accent = Color(0xFFC084FC); // purple-400 (6.9:1 on ink)
  static const accentDim = Color(0x2EC084FC); // purple-400 at 18%
  static const error = Color(0xFFF87171);

  static const radius = 14.0;
  static const gap = 16.0;
  static const railWidth = 72.0;
  static const cardW = 168.0, cardH = 112.0;
  static const wideW = 240.0, wideH = 135.0;
  static const hover = Duration(milliseconds: 120);
  static const slide = Duration(milliseconds: 220);
  static const slideCurve = Cubic(0.16, 1, 0.3, 1);

  static const display = 'Fraunces';
  static const ui = 'Manrope';
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Tokens.accent,
    onPrimary: Tokens.ink,
    surface: Tokens.panel,
    onSurface: Tokens.text,
    onSurfaceVariant: Tokens.textDim,
    outline: Tokens.line,
    error: Tokens.error,
    // Material defaults would bring a teal in (tonal buttons, chips): keep the
    // palette to the Glyph neutrals, purple and (support only) wine.
    secondary: Color(0xFFE77BA6), // wine-400
    onSecondary: Tokens.ink,
    secondaryContainer: Tokens.tileHi,
    onSecondaryContainer: Tokens.text,
    primaryContainer: Color(0xFF581C87), // purple-900
    onPrimaryContainer: Color(0xFFF3E8FF), // purple-100
    surfaceContainerHighest: Tokens.tileHi,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tokens.ink,
    fontFamily: Tokens.ui,
    splashFactory: NoSplash.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: Tokens.text, displayColor: Tokens.textStrong)
        .copyWith(
          titleLarge: const TextStyle(
            fontFamily: Tokens.display,
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
          headlineMedium: const TextStyle(
            fontFamily: Tokens.display,
            fontSize: 28,
            height: 32 / 28,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Tokens.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Tokens.line),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Tokens.accent, width: 2),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Tokens.accent,
      selectionColor: Tokens.accentDim,
    ),
  );
}
