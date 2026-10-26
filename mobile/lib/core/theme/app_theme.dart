import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/settings/settings.dart';

/// Money and status colours. They always come with words or arrows in the screens, never alone.
@immutable
class PasalColors extends ThemeExtension<PasalColors> {
  const PasalColors({
    required this.good,
    required this.warn,
    required this.bad,
    required this.info,
    required this.goodSoft,
    required this.warnSoft,
    required this.badSoft,
    required this.infoSoft,
  });

  final Color good;
  final Color warn;
  final Color bad;
  final Color info;
  final Color goodSoft;
  final Color warnSoft;
  final Color badSoft;
  final Color infoSoft;

  static const light = PasalColors(
    good: Color(0xFF17985A),
    warn: Color(0xFFDD7A0F),
    bad: Color(0xFFD83B3B),
    info: Color(0xFF2F6FDC),
    goodSoft: Color(0xFFE3F5EB),
    warnSoft: Color(0xFFFCEFDC),
    badSoft: Color(0xFFFBE6E6),
    infoSoft: Color(0xFFE4EDFB),
  );

  static const dark = PasalColors(
    good: Color(0xFF4BD08C),
    warn: Color(0xFFF5A149),
    bad: Color(0xFFF06A6A),
    info: Color(0xFF6F9FF5),
    goodSoft: Color(0xFF143525),
    warnSoft: Color(0xFF3A2812),
    badSoft: Color(0xFF3D1A1A),
    infoSoft: Color(0xFF172A4A),
  );

  @override
  PasalColors copyWith({
    Color? good,
    Color? warn,
    Color? bad,
    Color? info,
    Color? goodSoft,
    Color? warnSoft,
    Color? badSoft,
    Color? infoSoft,
  }) =>
      PasalColors(
        good: good ?? this.good,
        warn: warn ?? this.warn,
        bad: bad ?? this.bad,
        info: info ?? this.info,
        goodSoft: goodSoft ?? this.goodSoft,
        warnSoft: warnSoft ?? this.warnSoft,
        badSoft: badSoft ?? this.badSoft,
        infoSoft: infoSoft ?? this.infoSoft,
      );

  @override
  PasalColors lerp(ThemeExtension<PasalColors>? other, double t) {
    if (other is! PasalColors) return this;
    return PasalColors(
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      info: Color.lerp(info, other.info, t)!,
      goodSoft: Color.lerp(goodSoft, other.goodSoft, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      badSoft: Color.lerp(badSoft, other.badSoft, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
    );
  }
}

extension PasalThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  PasalColors get colors => Theme.of(this).extension<PasalColors>() ?? PasalColors.light;
}

/// Corner sizes, the same as the website and the prototype.
class Radii {
  Radii._();

  static const xl = 28.0;
  static const lg = 22.0;
  static const md = 16.0;
  static const sm = 12.0;
}

const _fontFamily = 'Inter';
const _fontFallback = ['NotoSansDevanagari'];

ThemeData buildTheme(AppSettings s, {Brightness? platformBrightness}) {
  final choice = s.theme;
  final dark = choice != ThemeChoice.light;
  final brightness = dark ? Brightness.dark : Brightness.light;
  var scheme = ColorScheme.fromSeed(seedColor: s.seedColor, brightness: brightness);

  if (choice == ThemeChoice.black) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0E0F10),
      surfaceContainer: const Color(0xFF0E0F10),
      surfaceContainerHigh: const Color(0xFF17191A),
      surfaceContainerHighest: const Color(0xFF1F2224),
    );
  } else if (!dark) {
    // A faint tint of the main colour, like the website background.
    scheme = scheme.copyWith(
      surface: Color.alphaBlend(s.seedColor.withValues(alpha: 0.05), const Color(0xFFF5F6F4)),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Color.alphaBlend(s.seedColor.withValues(alpha: 0.07), Colors.white),
    );
  }

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: scheme.surface,
  );

  final text = base.textTheme.apply(fontFamily: _fontFamily, fontFamilyFallback: _fontFallback);
  final line = scheme.outlineVariant.withValues(alpha: dark ? 0.4 : 0.6);

  return base.copyWith(
    textTheme: text,
    extensions: [dark ? PasalColors.dark : PasalColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: scheme.error, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: scheme.error, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        side: BorderSide(color: line, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: const StadiumBorder(), textStyle: const TextStyle(fontWeight: FontWeight.w600))),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: line),
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1C2124),
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      shape: const StadiumBorder(),
    ),
  );
}
