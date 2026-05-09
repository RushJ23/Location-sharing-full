import 'package:flutter/material.dart';

// Brand palette derived from Safe Circle logo
// Navy: #0D1B2E  Teal: #2DD4BF
const Color _primary = Color(0xFF0D9E91);           // teal-600, accessible on white
const Color _primaryContainer = Color(0xFFB2F5EC);  // teal-100
const Color _onPrimary = Colors.white;
const Color _navy = Color(0xFF0D1B2E);              // logo background navy
const Color _surface = Color(0xFFF8FFFE);           // near-white with cool tint
const Color _surfaceContainer = Color(0xFFEEFBF9);  // teal-50
const Color _onSurface = Color(0xFF0D1B2E);         // navy for text
const Color _onSurfaceVariant = Color(0xFF4A6572);
const Color _outline = Color(0xFFB0C4C8);
const Color _error = Color(0xFFDC2626);

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: _primary,
    onPrimary: _onPrimary,
    primaryContainer: _primaryContainer,
    onPrimaryContainer: const Color(0xFF134E4A),
    secondary: const Color(0xFF2DD4BF),             // logo teal (accent)
    onSecondary: _navy,
    secondaryContainer: const Color(0xFFCCFBF1),
    onSecondaryContainer: _navy,
    tertiary: _navy,                                 // navy as tertiary
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFF1E3A4F),
    onTertiaryContainer: Colors.white,
    surface: _surface,
    onSurface: _onSurface,
    surfaceContainerHighest: _surfaceContainer,
    onSurfaceVariant: _onSurfaceVariant,
    outline: _outline,
    error: _error,
    onError: Colors.white,
    errorContainer: const Color(0xFFFEE2E2),
    onErrorContainer: const Color(0xFF991B1B),
  ),
  scaffoldBackgroundColor: _surface,
  appBarTheme: AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: _surface,
    foregroundColor: _onSurface,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: const TextStyle(
      color: _onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: const IconThemeData(color: _onSurface, size: 24),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    color: Colors.white,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: _onPrimary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: _onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _primary,
      side: const BorderSide(color: _outline),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _primary,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: _onSurfaceVariant),
    hintStyle: const TextStyle(color: _onSurfaceVariant),
  ),
  listTileTheme: ListTileThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    titleTextStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: _onSurface,
    ),
    subtitleTextStyle: const TextStyle(
      fontSize: 14,
      color: _onSurfaceVariant,
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    backgroundColor: _onSurface,
    contentTextStyle: const TextStyle(color: _surface),
  ),
  dividerTheme: const DividerThemeData(color: _outline, thickness: 1),
);
