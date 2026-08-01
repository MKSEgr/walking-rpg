import 'package:flutter/material.dart';

abstract final class WalkingRpgColors {
  static const Color ink = Color(0xFF07151D);
  static const Color deepWater = Color(0xFF0B2028);
  static const Color nightPanel = Color(0xFF102A33);
  static const Color moonMist = Color(0xFFDDEDE8);
  static const Color lumen = Color(0xFF66E6BE);
  static const Color lumenDeep = Color(0xFF1FA982);
  static const Color energy = Color(0xFFFFC85A);
  static const Color resonance = Color(0xFFAE98FF);
  static const Color signalRed = Color(0xFFFF7C89);
}

@immutable
class WalkingRpgPalette extends ThemeExtension<WalkingRpgPalette> {
  const WalkingRpgPalette({
    required this.energy,
    required this.onEnergy,
    required this.resonance,
    required this.onResonance,
    required this.panelBorder,
    required this.panelHighlight,
    required this.backdropTop,
    required this.backdropBottom,
    required this.routeLine,
    required this.shadow,
  });

  final Color energy;
  final Color onEnergy;
  final Color resonance;
  final Color onResonance;
  final Color panelBorder;
  final Color panelHighlight;
  final Color backdropTop;
  final Color backdropBottom;
  final Color routeLine;
  final Color shadow;

  @override
  WalkingRpgPalette copyWith({
    Color? energy,
    Color? onEnergy,
    Color? resonance,
    Color? onResonance,
    Color? panelBorder,
    Color? panelHighlight,
    Color? backdropTop,
    Color? backdropBottom,
    Color? routeLine,
    Color? shadow,
  }) {
    return WalkingRpgPalette(
      energy: energy ?? this.energy,
      onEnergy: onEnergy ?? this.onEnergy,
      resonance: resonance ?? this.resonance,
      onResonance: onResonance ?? this.onResonance,
      panelBorder: panelBorder ?? this.panelBorder,
      panelHighlight: panelHighlight ?? this.panelHighlight,
      backdropTop: backdropTop ?? this.backdropTop,
      backdropBottom: backdropBottom ?? this.backdropBottom,
      routeLine: routeLine ?? this.routeLine,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  WalkingRpgPalette lerp(
    covariant ThemeExtension<WalkingRpgPalette>? other,
    double t,
  ) {
    if (other is! WalkingRpgPalette) {
      return this;
    }
    return WalkingRpgPalette(
      energy: Color.lerp(energy, other.energy, t)!,
      onEnergy: Color.lerp(onEnergy, other.onEnergy, t)!,
      resonance: Color.lerp(resonance, other.resonance, t)!,
      onResonance: Color.lerp(onResonance, other.onResonance, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      panelHighlight: Color.lerp(panelHighlight, other.panelHighlight, t)!,
      backdropTop: Color.lerp(backdropTop, other.backdropTop, t)!,
      backdropBottom: Color.lerp(backdropBottom, other.backdropBottom, t)!,
      routeLine: Color.lerp(routeLine, other.routeLine, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension WalkingRpgThemeContext on BuildContext {
  WalkingRpgPalette get walkingRpgPalette {
    final ThemeData theme = Theme.of(this);
    return theme.extension<WalkingRpgPalette>() ??
        (theme.brightness == Brightness.dark
            ? WalkingRpgTheme.darkPalette
            : WalkingRpgTheme.lightPalette);
  }
}

abstract final class WalkingRpgTheme {
  static const WalkingRpgPalette lightPalette = WalkingRpgPalette(
    energy: Color(0xFF9B5E00),
    onEnergy: Color(0xFFFFFFFF),
    resonance: Color(0xFF6C52C8),
    onResonance: Color(0xFFFFFFFF),
    panelBorder: Color(0xFFD2E3DD),
    panelHighlight: Color(0xFFFFFFFF),
    backdropTop: Color(0xFFE7F3EF),
    backdropBottom: Color(0xFFF7FAF8),
    routeLine: Color(0xFF65A892),
    shadow: Color(0x2E06271E),
  );

  static const WalkingRpgPalette darkPalette = WalkingRpgPalette(
    energy: WalkingRpgColors.energy,
    onEnergy: Color(0xFF2C1D00),
    resonance: WalkingRpgColors.resonance,
    onResonance: Color(0xFF1D1343),
    panelBorder: Color(0xFF294650),
    panelHighlight: Color(0xFF183843),
    backdropTop: WalkingRpgColors.deepWater,
    backdropBottom: WalkingRpgColors.ink,
    routeLine: Color(0xFF4D8B7A),
    shadow: Color(0xB300090D),
  );

  static ThemeData light() {
    final ColorScheme colors =
        ColorScheme.fromSeed(
          seedColor: WalkingRpgColors.lumenDeep,
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF08785C),
          onPrimary: Colors.white,
          secondary: const Color(0xFF52645E),
          tertiary: const Color(0xFF6C52C8),
          error: const Color(0xFFB3263E),
          surface: const Color(0xFFF7FAF8),
          surfaceContainer: const Color(0xFFEAF2EE),
          surfaceContainerHigh: const Color(0xFFE0EBE6),
          surfaceContainerHighest: const Color(0xFFD7E5DF),
        );
    return _build(
      colors: colors,
      palette: lightPalette,
      scaffoldBackground: const Color(0xFFF7FAF8),
    );
  }

  static ThemeData dark() {
    final ColorScheme colors =
        ColorScheme.fromSeed(
          seedColor: WalkingRpgColors.lumen,
          brightness: Brightness.dark,
        ).copyWith(
          primary: WalkingRpgColors.lumen,
          onPrimary: const Color(0xFF002118),
          primaryContainer: const Color(0xFF174D40),
          onPrimaryContainer: const Color(0xFFC8F8E8),
          secondary: const Color(0xFFB6CCC4),
          onSecondary: const Color(0xFF213630),
          secondaryContainer: const Color(0xFF2B413A),
          onSecondaryContainer: const Color(0xFFD2E8DF),
          tertiary: WalkingRpgColors.resonance,
          onTertiary: const Color(0xFF271855),
          error: WalkingRpgColors.signalRed,
          surface: WalkingRpgColors.ink,
          surfaceContainer: WalkingRpgColors.deepWater,
          surfaceContainerHigh: WalkingRpgColors.nightPanel,
          surfaceContainerHighest: const Color(0xFF183843),
          onSurface: WalkingRpgColors.moonMist,
          onSurfaceVariant: const Color(0xFFB8C9C4),
          outline: const Color(0xFF6E817B),
          outlineVariant: const Color(0xFF344B45),
        );
    return _build(
      colors: colors,
      palette: darkPalette,
      scaffoldBackground: WalkingRpgColors.ink,
    );
  }

  static ThemeData _build({
    required ColorScheme colors,
    required WalkingRpgPalette palette,
    required Color scaffoldBackground,
  }) {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: scaffoldBackground,
    );
    final TextTheme text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.06,
        letterSpacing: -0.9,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -0.7,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.14,
        letterSpacing: -0.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.22,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.42),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );

    final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: palette.panelBorder),
    );
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.9),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colors.surfaceContainerHigh,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((
          Set<WidgetState> states,
        ) {
          return text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((
          Set<WidgetState> states,
        ) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: colors.outlineVariant),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        linearMinHeight: 8,
        borderRadius: BorderRadius.circular(999),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant.withValues(alpha: 0.8),
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
