import 'package:flutter/material.dart';

abstract final class AppColors {
  static const acid = Color(0xFFA8F47C);
  static const acidSoft = Color(0xFFE8FBD9);
  static const green = Color(0xFF2E8058);
  static const greenBright = Color(0xFF68B783);
  static const greenDark = Color(0xFF102617);
  static const lime = Color(0xFFC9F59F);
  static const aqua = Color(0xFFA8DFC0);
  static const greenSoft = Color(0xFFE7F3E8);
  static const mint = Color(0xFFCFE8D2);
  static const canvas = Color(0xFFF7F8F0);
  static const ink = Color(0xFF102617);
  static const inkSoft = Color(0xFF607066);
  static const line = Color(0xFFDDE6DA);
  static const warning = Color(0xFFF5A623);
  static const warningSoft = Color(0xFFFFF5DF);
  static const danger = Color(0xFFD94040);
  static const dangerSoft = Color(0xFFFFECEC);
}

abstract final class AppGradients {
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3C8D62), Color(0xFF205C3B), Color(0xFF102617)],
    stops: [0, 0.48, 1],
  );

  static const primarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2FBE8), Color(0xFFE7F5E4), Color(0xFFDEF0E5)],
  );

  static const page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEAF9DF), Color(0xFFF7F8F0), Color(0xFFFFFFFF)],
    stops: [0, 0.42, 1],
  );

  static const sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF1F8D9), Color(0xFFE2F1E2)],
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
      surface: Colors.white,
      background: AppColors.canvas,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: 'SF Pro Display',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: AppColors.ink,
          fontSize: 36,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 27,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        headlineSmall: TextStyle(
          color: AppColors.ink,
          fontSize: 21,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: AppColors.inkSoft,
          fontSize: 14,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFEFFFE),
        surfaceTintColor: Colors.white,
        elevation: 1.5,
        shadowColor: AppColors.greenDark.withOpacity(0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFCFFFD),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        hintStyle: const TextStyle(color: AppColors.inkSoft),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.acid,
          foregroundColor: AppColors.greenDark,
          minimumSize: const Size.fromHeight(56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        backgroundColor: const Color(0xFFF8FFF9),
        surfaceTintColor: Colors.white,
        indicatorColor: AppColors.acidSoft,
        elevation: 8,
        shadowColor: AppColors.greenDark.withOpacity(0.1),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(MaterialState.selected)
                ? AppColors.greenDark
                : AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    );
  }
}
