import 'package:flutter/material.dart';

/// Colors from brand/brand.json.
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.background,
    required this.muted,
    required this.water,
    required this.outline,
  });

  final Color background;
  final Color muted;
  final Color water;
  final Color outline;

  static const light = BrandColors(
    background: Color(0xFFF3F8FC),
    muted: Color(0xFF4C6275),
    water: Color(0xFF1F9AA6),
    outline: Color(0xFFDCE6EE),
  );

  static const dark = BrandColors(
    background: Color(0xFF0B1620),
    muted: Color(0xFFA9BCCB),
    water: Color(0xFF5ED6DF),
    outline: Color(0x00000000),
  );

  static BrandColors of(BuildContext context) =>
      Theme.of(context).extension<BrandColors>()!;

  @override
  BrandColors copyWith({
    Color? background,
    Color? muted,
    Color? water,
    Color? outline,
  }) => BrandColors(
    background: background ?? this.background,
    muted: muted ?? this.muted,
    water: water ?? this.water,
    outline: outline ?? this.outline,
  );

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    return BrandColors(
      background: Color.lerp(background, other.background, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      water: Color.lerp(water, other.water, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

const _font = 'Nunito';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final brand = dark ? BrandColors.dark : BrandColors.light;
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B5CAD),
    brightness: brightness,
  );
  final scheme = dark
      ? base.copyWith(
          primary: const Color(0xFF8CC8FF),
          onPrimary: const Color(0xFF00315C),
          secondary: const Color(0xFF5ED6DF),
          onSecondary: const Color(0xFF00363B),
          surface: const Color(0xFF13222F),
          onSurface: const Color(0xFFE3EEF7),
          error: const Color(0xFFFFB4AB),
          surfaceContainerHighest: const Color(0xFF1C3040),
        )
      : base.copyWith(
          primary: const Color(0xFF0B5CAD),
          onPrimary: const Color(0xFFFFFFFF),
          secondary: const Color(0xFF1F9AA6),
          onSecondary: const Color(0xFFFFFFFF),
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF0F2233),
          error: const Color(0xFFB3261E),
        );
  final text = Typography.material2021(platform: TargetPlatform.android)
      .englishLike
      .merge(dark ? Typography.whiteMountainView : Typography.blackMountainView)
      .apply(
        fontFamily: _font,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      )
      .copyWith(
        displaySmall: TextStyle(
          fontFamily: _font,
          fontSize: 36,
          height: 44 / 36,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontFamily: _font,
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: _font,
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontFamily: _font,
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        labelLarge: TextStyle(
          fontFamily: _font,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: _font,
    textTheme: text,
    scaffoldBackgroundColor: brand.background,
    extensions: [brand],
    appBarTheme: AppBarTheme(
      backgroundColor: brand.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: text.titleLarge,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: dark ? BorderSide.none : BorderSide(color: brand.outline),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : brand.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? scheme.primary
              : brand.muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        backgroundColor: scheme.primary.withValues(alpha: dark ? 0.12 : 0.06),
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
