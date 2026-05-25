import 'package:flutter/material.dart';

class AppTheme {
  // ─── Brand colors ────────────────────────────────────────────
  static const _seed = Color(0xFF1B6B5A);
  static const accent = Color(0xFFE8593C);
  static const gold = Color(0xFFD4A53C);
  static const emerald = Color(0xFF2E8B6E);
  static const sky = Color(0xFF4A9BD9);
  static const lavender = Color(0xFF7B68C4);

  // ─── Comparison / grading colors ────────────────────────────
  static const correctBg = Color(0xFFD5F5E3);
  static const correctBorder = Color(0xFF52BE80);
  static const correctFg = Color(0xFF145A32);
  static const minorBg = Color(0xFFFEF9E7);
  static const minorBorder = Color(0xFFF4D35E);
  static const minorFg = Color(0xFF7D6608);
  static const wrongBg = Color(0xFFFDEDED);
  static const wrongBorder = Color(0xFFE57373);
  static const wrongFg = Color(0xFF922B21);

  static const correctBgDark = Color(0xFF1A3D2A);
  static const correctBorderDark = Color(0xFF388E5C);
  static const correctFgDark = Color(0xFF81C784);
  static const minorBgDark = Color(0xFF3D3519);
  static const minorBorderDark = Color(0xFFC9A824);
  static const minorFgDark = Color(0xFFE8C76A);
  static const wrongBgDark = Color(0xFF3D1A1A);
  static const wrongBorderDark = Color(0xFFD32F2F);
  static const wrongFgDark = Color(0xFFEF9A9A);

  // ─── Gradients ──────────────────────────────────────────────
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF1B6B5A), Color(0xFF2E8B6E), Color(0xFF4ABFA0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradientDark = LinearGradient(
    colors: [Color(0xFF0D3D32), Color(0xFF1A5C4A), Color(0xFF267D64)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warmGradient = LinearGradient(
    colors: [Color(0xFFE8593C), Color(0xFFF2994A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFD4A53C), Color(0xFFE8C76A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shared constants ───────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusRound = 999;

  static BorderRadius borderSm = BorderRadius.circular(radiusSm);
  static BorderRadius borderMd = BorderRadius.circular(radiusMd);
  static BorderRadius borderLg = BorderRadius.circular(radiusLg);
  static BorderRadius borderXl = BorderRadius.circular(radiusXl);

  static List<BoxShadow> shadowSm(Brightness brightness) => [
        BoxShadow(
          color: brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowMd(Brightness brightness) => [
        BoxShadow(
          color: brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> shadowLg(Brightness brightness) => [
        BoxShadow(
          color: brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.08),
          blurRadius: 36,
          offset: const Offset(0, 12),
        ),
      ];

  // ─── Light Theme ────────────────────────────────────────────
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: _seed,
      secondary: accent,
      tertiary: gold,
      surface: const Color(0xFFF7FAF8),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF1F6F3),
      surfaceContainer: const Color(0xFFEAF0EC),
      surfaceContainerHigh: const Color(0xFFE1EBE5),
      surfaceContainerHighest: const Color(0xFFD6E3DC),
      outline: const Color(0xFF8FA6A0),
      outlineVariant: const Color(0xFFCEDBD6),
      error: const Color(0xFFB3261E),
    );
    return _buildTheme(scheme, Brightness.light);
  }

  // ─── Dark Theme ─────────────────────────────────────────────
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF5BC9A8),
      secondary: const Color(0xFFFF8A70),
      tertiary: const Color(0xFFE8C76A),
      surface: const Color(0xFF0E1513),
      surfaceContainerLowest: const Color(0xFF111B18),
      surfaceContainerLow: const Color(0xFF161F1C),
      surfaceContainer: const Color(0xFF1C2724),
      surfaceContainerHigh: const Color(0xFF243330),
      surfaceContainerHighest: const Color(0xFF2C3D38),
      outline: const Color(0xFF5E7B73),
      outlineVariant: const Color(0xFF334843),
      error: const Color(0xFFFF897D),
    );
    return _buildTheme(scheme, Brightness.dark);
  }

  // ─── Build ──────────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      fontFamilyFallback: const [
        'Segoe UI',
        'Roboto',
        'SF Pro Display',
        'Arial',
      ],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: borderMd,
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 1.0),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: borderSm),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: borderMd,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderMd,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(52, 48),
          shape: RoundedRectangleBorder(borderRadius: borderMd),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(52, 46),
          shape: RoundedRectangleBorder(borderRadius: borderMd),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: borderSm),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: borderMd),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radiusRound),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: borderXl),
        elevation: 6,
        backgroundColor: scheme.surfaceContainerLowest,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
        elevation: 8,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: borderMd),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: borderSm,
        ),
        textStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
