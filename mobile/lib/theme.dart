import 'package:flutter/material.dart';

/// "Atelier" palette: deep plum like a boutique's velvet curtain, champagne
/// gold like tailor's thread, and a soft ivory like fresh fabric.
class AppColors {
  static const plum = Color(0xFF3D1F4E);
  static const plumDeep = Color(0xFF26122F);
  static const plumSoft = Color(0xFF6B3F80);
  static const gold = Color(0xFFC9A45C);
  static const goldSoft = Color(0xFFF3E6C8);
  static const ivory = Color(0xFFFBF7F2);
  static const ink = Color(0xFF1F1724);
  static const muted = Color(0xFF7C7083);
  static const line = Color(0xFFE9E1EC);

  static const available = Color(0xFF2E9E6A);
  static const onRent = Color(0xFFE08A1E);
  static const overdue = Color(0xFFD64545);
  static const booked = Color(0xFF4C6FD6);
  static const returned = Color(0xFF8A8A8A);

  static Color forStatus(String s) => switch (s) {
        'available' => available,
        'on_rent' => onRent,
        'overdue' => overdue,
        'booked' => booked,
        _ => returned,
      };

  static String label(String s) => switch (s) {
        'available' => 'Available',
        'on_rent' => 'On Rent',
        'overdue' => 'Overdue',
        'booked' => 'Booked',
        'returned' => 'Returned',
        _ => s,
      };

  static IconData icon(String s) => switch (s) {
        'available' => Icons.check_circle_rounded,
        'on_rent' => Icons.shopping_bag_rounded,
        'overdue' => Icons.warning_rounded,
        'booked' => Icons.event_available_rounded,
        _ => Icons.assignment_turned_in_rounded,
      };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.plum,
    primary: AppColors.plum,
    secondary: AppColors.gold,
    surface: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: AppColors.line),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ivory,
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ivory,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.plum, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.plum,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.plum,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: AppColors.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.goldSoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: AppColors.line),
    ),
  );
}
