import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens - festive premium dark.
class SoluColors {
  static const canvas = Color(0xFF0B0A0F);
  static const surface = Color(0xFF15131C);
  static const raised = Color(0xFF1E1B27);
  static const stroke = Color(0x1FFFFFFF);

  static const brand = Color(0xFFFF7A29);
  static const brandAlt = Color(0xFFFFC24B);
  static const violet = Color(0xFF8B5CF6);

  static const text = Color(0xFFF7F6FA);
  static const textMuted = Color(0xFF9A96A8);
  static const success = Color(0xFF4ADE80);
  static const error = Color(0xFFF87171);

  static const brandGradient = LinearGradient(
    colors: [brand, brandAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const divineGradient = LinearGradient(
    colors: [Color(0xFFFFE9B0), Color(0xFFFFC24B), Color(0xFFFF9A3D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class SoluRadius {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class SoluTheme {
  static void applySystemChrome() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SoluColors.canvas,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: SoluColors.canvas,
      colorScheme: base.colorScheme.copyWith(
        primary: SoluColors.brand,
        secondary: SoluColors.violet,
        surface: SoluColors.surface,
        error: SoluColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: SoluColors.text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: SoluColors.text),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: SoluColors.text, displayColor: SoluColors.text)
          .copyWith(
            headlineLarge: const TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, height: 1.15),
            headlineMedium: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
            titleLarge: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, height: 1.25),
            bodyLarge: const TextStyle(fontSize: 15, height: 1.45),
            bodyMedium: const TextStyle(fontSize: 13.5, height: 1.45),
            labelSmall: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: SoluColors.raised,
        contentTextStyle: TextStyle(color: SoluColors.text),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SoluColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: SoluColors.stroke,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
