import 'package:flutter/material.dart';
import 'color_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: MeshColors.primaryLight,
        secondary: MeshColors.secondaryLight,
        surface: MeshColors.surfaceLight,
        onSurface: MeshColors.textPrimaryLight,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: MeshColors.primaryDark,
        secondary: MeshColors.secondaryDark,
        surface: MeshColors.surfaceDark,
        onSurface: MeshColors.textPrimaryDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color surface,
    required Color onSurface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      surface: surface,
      onSurface: onSurface,
      error: MeshColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}
