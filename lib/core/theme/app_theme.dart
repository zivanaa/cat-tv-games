import 'package:flutter/material.dart';

/// The app's colours.
///
/// Deliberately the same water and gold the pond is painted with. The two
/// surfaces are tuned for different eyes — the cat surface is built around
/// luminance contrast because that is what a cat resolves, this one is built to
/// be looked at by a person — but they should still read as one product, and
/// sharing the hues is what does that.
abstract final class AppColours {
  static const deep = Color(0xFF04182B);
  static const water = Color(0xFF0D4468);
  static const shallow = Color(0xFF1C7A96);

  static const gold = Color(0xFFFFCF5C);
  static const amber = Color(0xFFFF9E2C);
  static const teal = Color(0xFF56D9C4);

  static const ink = Color(0xFFF2F7FA);
  static const muted = Color(0xFF8FB4CC);
  static const faint = Color(0xFF5C819B);
  static const line = Color(0x3356D9C4);
}

/// The human surface's theme.
///
/// Dark, because this is an app you open in a living room with a cat on the
/// floor, and because it is the same water the cat is looking at. Gold is the
/// only thing allowed to be bright: on the cat surface that is a hard rule
/// about what a cat can resolve, and carrying it over here keeps the one thing
/// worth tapping obvious.
abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColours.gold,
      onPrimary: AppColours.deep,
      secondary: AppColours.teal,
      onSecondary: AppColours.deep,
      surface: AppColours.deep,
      onSurface: AppColours.ink,
      outline: AppColours.line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColours.deep,
      // No custom font. A typeface is a licensed asset, and the same rule that
      // kept downloaded audio out of this repo applies to one: whatever ships
      // in a store carries its licence with it. Roboto is already there.
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: AppColours.gold,
          fontSize: 44,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        titleMedium: TextStyle(
          color: AppColours.ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: AppColours.muted, fontSize: 15),
        bodySmall: TextStyle(color: AppColours.faint, fontSize: 13),
        labelLarge: TextStyle(
          color: AppColours.teal,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColours.gold,
          foregroundColor: AppColours.deep,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  /// The backdrop every human screen sits on: deep water with the light
  /// pooling high, so the eye lands near the top where the title is.
  static BoxDecoration get backdrop => const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.55),
          radius: 1.1,
          colors: [AppColours.water, AppColours.deep],
          stops: [0, 0.85],
        ),
      );
}
