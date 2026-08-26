import 'package:flutter/material.dart';

/// Spotify-inspired dark palette.
class AppColors {
  // Backgrounds & surfaces
  static const background = Color(0xFF121212); // base app background
  static const surface = Color(0xFF181818); // elevated surface (cards, sheets)
  static const surfaceElevated = Color(0xFF181818);
  static const card = Color(0xFF282828); // raised cards / list rows
  static const inputFill = Color(0xFF2A2A2A); // search / text fields
  static const navBackground = Color(0xFF000000); // bottom navigation bar

  // Brand accent
  static const primary = Color(0xFF1DB954); // Spotify green
  static const greenBright = Color(0xFF1ED760); // pressed / hover
  static const secondary = Color(0xFF1ED760);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);

  // Feedback
  static const error = Color(0xFFE22134);

  AppColors._();
}
