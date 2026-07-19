import 'package:flutter/material.dart';

/// Design tokens — voir CLAUDE.md § Exigences transversales (accessibilité, performance).
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF5F6F8);
  static const primary = Color(0xFF1F8A55);
  static const primaryDark = Color(0xFF166B41);
  static const text = Color(0xFF171A1F);
  static const textMuted = Color(0xFF5B6270);
  static const border = Color(0xFFE1E4E9);
  static const danger = Color(0xFFD64545);
  static const disabled = Color(0xFFC7CBD1);
  // Distinct du vert primaire (bouton "Acheter") et du rouge "Épuisé" —
  // badge Promo (demande utilisateur : une couleur qui le distingue des
  // autres badges/boutons de la tuile produit).
  static const promo = Color(0xFFE07A1F);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Accessibilité : police min 14px, boutons min 44px de hauteur (specs §4.2).
class AppLayout {
  static const minTouchHeight = 44.0;
  static const radius = 12.0;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.background,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.text),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        minimumSize: const Size.fromHeight(AppLayout.minTouchHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: const Size.fromHeight(AppLayout.minTouchHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radius)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
    ),
  );
}
