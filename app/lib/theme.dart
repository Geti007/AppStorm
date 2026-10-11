import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'state/app_state.dart';

/// Colours from brand/brand.json and DESIGN.md §2.
class Brand {
  static const font = 'PlusJakartaSans';

  static const lightBackground = Color(0xFFF6F4EF);
  static const lightOnBackground = Color(0xFF14232B);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurfaceVariant = Color(0xFF4A5A61);
  static const lightOutline = Color(0xFFD9D4CA);
  static const lightError = Color(0xFFB3261E);

  static const darkBackground = Color(0xFF0D171C);
  static const darkOnBackground = Color(0xFFE6EEF0);
  static const darkSurface = Color(0xFF15232A);
  static const darkOnSurfaceVariant = Color(0xFFA9B8BE);
  static const darkOutline = Color(0xFF2B3A41);
  static const darkError = Color(0xFFFFB4AB);

  static const positiveLight = Color(0xFF1B7F4B);
  static const positiveDark = Color(0xFF6FD39B);
}

class _Accent {
  const _Accent(
    this.primary,
    this.secondary,
    this.darkPrimary,
    this.darkSecondary,
  );

  final Color primary;
  final Color secondary;
  final Color darkPrimary;
  final Color darkSecondary;
}

const Map<AccentTheme, _Accent> _accents = {
  AccentTheme.lagoon: _Accent(
    Color(0xFF0E6E74),
    Color(0xFFE8603F),
    Color(0xFF5CC8C2),
    Color(0xFFFF9A7E),
  ),
  AccentTheme.sunset: _Accent(
    Color(0xFFB83B5E),
    Color(0xFFF08A5D),
    Color(0xFFF4A27F),
    Color(0xFFF49AC8),
  ),
  AccentTheme.forest: _Accent(
    Color(0xFF2F6B47),
    Color(0xFFD9A441),
    Color(0xFF7CC79A),
    Color(0xFFE6B95A),
  ),
  AccentTheme.midnight: _Accent(
    Color(0xFF2E3A87),
    Color(0xFF5CC8C2),
    Color(0xFF9FA8F0),
    Color(0xFF7FD6D0),
  ),
};

/// The swatch colour shown for an accent theme in Settings.
Color accentSwatch(AccentTheme a) => _accents[a]!.primary;

String accentName(AccentTheme a) => switch (a) {
  AccentTheme.lagoon => 'Lagoon',
  AccentTheme.sunset => 'Sunset',
  AccentTheme.forest => 'Forest',
  AccentTheme.midnight => 'Midnight',
};

/// Trip cover gradients (DESIGN.md §2), by the index stored on a trip.
const List<(String, Color, Color)> tripCovers = [
  ('Lagoon', Color(0xFF13898E), Color(0xFF0A4F57)),
  ('Sunset', Color(0xFFF08A5D), Color(0xFFB83B5E)),
  ('Forest', Color(0xFF3C8D5A), Color(0xFF1E4D3A)),
  ('Midnight', Color(0xFF2E3A87), Color(0xFF141B3D)),
  ('Sand', Color(0xFFE3C79A), Color(0xFF8A6238)),
  ('Sky', Color(0xFF5AB2E8), Color(0xFF2266A8)),
];

LinearGradient coverGradient(int index) {
  final c = tripCovers[index % tripCovers.length];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [c.$2, c.$3],
  );
}

/// The dashboard band: the darker half of the cover, darkest on the left
/// where the white text sits.
LinearGradient headerGradient(int index) {
  final c = tripCovers[index % tripCovers.length];
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [c.$3, Color.lerp(c.$3, c.$2, 0.55)!],
  );
}

Color positiveColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Brand.positiveDark
    : Brand.positiveLight;

ThemeData buildTheme(Brightness brightness, AccentTheme accent) {
  final dark = brightness == Brightness.dark;
  final a = _accents[accent]!;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? a.darkPrimary : a.primary,
    onPrimary: dark ? const Color(0xFF0D171C) : Colors.white,
    primaryContainer: (dark ? a.darkPrimary : a.primary).withValues(
      alpha: 0.16,
    ),
    onPrimaryContainer: dark ? Brand.darkOnBackground : Brand.lightOnBackground,
    secondary: dark ? a.darkSecondary : a.secondary,
    onSecondary: dark ? const Color(0xFF2B1A14) : const Color(0xFF14232B),
    secondaryContainer: (dark ? a.darkSecondary : a.secondary).withValues(
      alpha: 0.18,
    ),
    onSecondaryContainer: dark
        ? Brand.darkOnBackground
        : Brand.lightOnBackground,
    error: dark ? Brand.darkError : Brand.lightError,
    onError: dark ? const Color(0xFF690005) : Colors.white,
    surface: dark ? Brand.darkSurface : Brand.lightSurface,
    onSurface: dark ? Brand.darkOnBackground : Brand.lightOnBackground,
    onSurfaceVariant: dark
        ? Brand.darkOnSurfaceVariant
        : Brand.lightOnSurfaceVariant,
    outline: dark ? Brand.darkOutline : Brand.lightOutline,
    outlineVariant: dark ? Brand.darkOutline : Brand.lightOutline,
    surfaceContainerLowest: dark ? Brand.darkBackground : Brand.lightBackground,
    surfaceContainerLow: dark
        ? const Color(0xFF122027)
        : const Color(0xFFFBFAF7),
    surfaceContainer: dark ? Brand.darkSurface : Brand.lightSurface,
    surfaceContainerHigh: dark
        ? const Color(0xFF1B2B33)
        : const Color(0xFFF1EEE7),
    surfaceContainerHighest: dark
        ? const Color(0xFF22343D)
        : const Color(0xFFEAE6DD),
  );
  final background = dark ? Brand.darkBackground : Brand.lightBackground;
  final onBackground = dark ? Brand.darkOnBackground : Brand.lightOnBackground;

  const tabular = [FontFeature.tabularFigures()];
  final text =
      TextTheme(
        displaySmall: const TextStyle(
          fontSize: 36,
          height: 44 / 36,
          fontWeight: FontWeight.w700,
          fontFeatures: tabular,
        ),
        headlineSmall: const TextStyle(
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
          fontFeatures: tabular,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 24 / 16),
        bodyMedium: const TextStyle(fontSize: 14, height: 20 / 14),
        labelLarge: const TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: const TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
        ),
      ).apply(
        fontFamily: Brand.font,
        bodyColor: onBackground,
        displayColor: onBackground,
      );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  const buttonSize = Size(64, 52);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: Brand.font,
    textTheme: text,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: onBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: dark ? BorderSide(color: scheme.outline) : BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      extendedTextStyle: text.labelLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1B2B33) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: text.labelLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    tabBarTheme: TabBarThemeData(
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
