import 'package:flutter/material.dart';

/// The HabitPulse colour palette.
///
/// Dark is the default theme: a near-black background with slightly lighter
/// rounded cards and a green accent, matching the style in the product spec.
abstract final class AppColors {
  /// Primary accent used for buttons and the completed state.
  static const Color green = Color(0xFF4ADE80);
  static const Color greenStrong = Color(0xFF16A34A);

  // ---------------------------------------------------------------- dark theme
  static const Color darkBackground = Color(0xFF0A0C10);
  static const Color darkSurface = Color(0xFF12151B);
  static const Color darkCard = Color(0xFF171B22);
  static const Color darkBorder = Color(0xFF252B35);
  static const Color darkText = Color(0xFFF2F5F9);
  static const Color darkMuted = Color(0xFF98A1AF);

  // --------------------------------------------------------------- light theme
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE3E7ED);
  static const Color lightText = Color(0xFF11151A);
  static const Color lightMuted = Color(0xFF667085);

  static const Color error = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);

  /// The twelve accent colours a habit can be tinted with (section 2).
  static const List<Color> accents = <Color>[
    Color(0xFF4ADE80), // green
    Color(0xFF2DD4BF), // teal
    Color(0xFF22D3EE), // cyan
    Color(0xFF60A5FA), // blue
    Color(0xFF818CF8), // indigo
    Color(0xFFA78BFA), // violet
    Color(0xFFC084FC), // purple
    Color(0xFFF472B6), // pink
    Color(0xFFFB7185), // rose
    Color(0xFFF87171), // red
    Color(0xFFFB923C), // orange
    Color(0xFFFBBF24), // amber
  ];

  /// Resolves a stored hex string (e.g. `#4ADE80`) back to a [Color].
  static Color fromHex(String hex, {Color fallback = green}) {
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6 && cleaned.length != 8) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }

  /// Formats a [Color] as `#RRGGBB` for storage.
  static String toHex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
