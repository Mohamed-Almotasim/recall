import 'package:flutter/material.dart';

/// Semantic colours for the four grades.
@immutable
class GradeColors extends ThemeExtension<GradeColors> {
  const GradeColors({
    required this.again,
    required this.hard,
    required this.good,
    required this.easy,
  });

  final Color again;
  final Color hard;
  final Color good;
  final Color easy;

  static const light = GradeColors(
    again: Color(0xFFA8473A),
    hard: Color(0xFFB07A1E),
    good: Color(0xFF1F6F5C),
    easy: Color(0xFF3D6A8E),
  );
  static const dark = GradeColors(
    again: Color(0xFFE0806F),
    hard: Color(0xFFD9A441),
    good: Color(0xFF6FBFA6),
    easy: Color(0xFF7FB0D6),
  );

  @override
  GradeColors copyWith({Color? again, Color? hard, Color? good, Color? easy}) =>
      GradeColors(
        again: again ?? this.again,
        hard: hard ?? this.hard,
        good: good ?? this.good,
        easy: easy ?? this.easy,
      );

  @override
  GradeColors lerp(GradeColors? other, double t) => other == null
      ? this
      : GradeColors(
          again: Color.lerp(again, other.again, t)!,
          hard: Color.lerp(hard, other.hard, t)!,
          good: Color.lerp(good, other.good, t)!,
          easy: Color.lerp(easy, other.easy, t)!,
        );
}

/// Surface tokens that do not fit ColorScheme.
@immutable
class PaperColors extends ThemeExtension<PaperColors> {
  const PaperColors({required this.card, required this.shadow});

  final Color card;
  final Color shadow;

  static const light = PaperColors(
    card: Color(0xFFFFFFFF),
    shadow: Color(0x331B1A17),
  );
  static const dark = PaperColors(
    card: Color(0xFF26251F),
    shadow: Color(0x99000000),
  );

  @override
  PaperColors copyWith({Color? card, Color? shadow}) =>
      PaperColors(card: card ?? this.card, shadow: shadow ?? this.shadow);

  @override
  PaperColors lerp(PaperColors? other, double t) => other == null
      ? this
      : PaperColors(
          card: Color.lerp(card, other.card, t)!,
          shadow: Color.lerp(shadow, other.shadow, t)!,
        );
}

const arabicFont = 'PlexArabic';

class AppTheme {
  static const _accentLight = Color(0xFF1F6F5C);
  static const _accentDark = Color(0xFF6FBFA6);

  static ThemeData light(Locale locale) => _build(
    locale,
    ColorScheme.light(
      primary: _accentLight,
      primaryContainer: const Color(0xFFD7E8E2),
      onPrimaryContainer: const Color(0xFF0E3A30),
      surface: const Color(0xFFF6F2EA),
      onSurface: const Color(0xFF1B1A17),
      onSurfaceVariant: const Color(0xFF5E5B53),
      surfaceContainerLow: const Color(0xFFEFEADF),
      surfaceContainer: const Color(0xFFEAE4D7),
      surfaceContainerHighest: const Color(0xFFE2DBCB),
      outline: const Color(0xFF8D887B),
      outlineVariant: const Color(0xFFD6CFBF),
      error: GradeColors.light.again,
    ),
    GradeColors.light,
    PaperColors.light,
  );

  static ThemeData dark(Locale locale) => _build(
    locale,
    ColorScheme.dark(
      primary: _accentDark,
      onPrimary: const Color(0xFF07251D),
      primaryContainer: const Color(0xFF1C4A3E),
      onPrimaryContainer: const Color(0xFFCDE9E0),
      surface: const Color(0xFF181713),
      onSurface: const Color(0xFFECE7DB),
      onSurfaceVariant: const Color(0xFFA9A497),
      surfaceContainerLow: const Color(0xFF1F1E19),
      surfaceContainer: const Color(0xFF24231E),
      surfaceContainerHighest: const Color(0xFF302F28),
      outline: const Color(0xFF7C786C),
      outlineVariant: const Color(0xFF3A3830),
      error: GradeColors.dark.again,
    ),
    GradeColors.dark,
    PaperColors.dark,
  );

  static ThemeData _build(
    Locale locale,
    ColorScheme scheme,
    GradeColors grades,
    PaperColors paper,
  ) {
    final ar = locale.languageCode == 'ar';
    final body = ar ? arabicFont : 'SourceSans3';
    const fallback = [arabicFont];

    TextStyle display(double size, {double h = 1.15}) => TextStyle(
      fontFamily: ar ? arabicFont : 'Fraunces',
      fontFamilyFallback: fallback,
      fontSize: size,
      height: h,
      fontWeight: FontWeight.w600,
      fontVariations: ar
          ? null
          : const [FontVariation('wght', 600), FontVariation('opsz', 48)],
      letterSpacing: ar ? 0 : -0.4,
      color: scheme.onSurface,
    );

    TextStyle text(
      double size, {
      FontWeight w = FontWeight.w400,
      double h = 1.4,
    }) => TextStyle(
      fontFamily: body,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: w,
      height: h,
      color: scheme.onSurface,
    );

    final textTheme = TextTheme(
      displaySmall: display(36),
      headlineMedium: display(30),
      headlineSmall: display(24),
      titleLarge: display(21),
      titleMedium: text(17, w: FontWeight.w600),
      titleSmall: text(15, w: FontWeight.w600),
      bodyLarge: text(17, h: 1.5),
      bodyMedium: text(15, h: 1.45),
      bodySmall: text(13),
      labelLarge: text(15, w: FontWeight.w600),
      labelMedium: text(13, w: FontWeight.w600),
      labelSmall: text(11.5, w: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      fontFamily: body,
      fontFamilyFallback: fallback,
      extensions: [grades, paper],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelType: NavigationRailLabelType.all,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}

extension ThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  GradeColors get grades => Theme.of(this).extension<GradeColors>()!;
  PaperColors get paper => Theme.of(this).extension<PaperColors>()!;
}
