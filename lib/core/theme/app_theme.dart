import 'package:flutter/material.dart';
import 'color_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: MeshColors.fab,
      brightness: Brightness.dark,
    ).copyWith(
      surface: MeshColors.canvas,
      onSurface: MeshColors.textPrimary,
      error: MeshColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: MeshColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MeshColors.fab,
        foregroundColor: MeshColors.textPrimary,
        elevation: 4,
      ),
    );
  }
}
