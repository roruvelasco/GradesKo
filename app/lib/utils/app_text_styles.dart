import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pre-cached text styles to improve performance
/// Instead of calling GoogleFonts.poppins() repeatedly, use these cached styles
class AppTextStyles {
  AppTextStyles._();

  // Initialize all text styles once when the app starts
  static late final TextStyle _baseStyle;

  // Common text styles
  static late final TextStyle heading1;
  static late final TextStyle heading2;
  static late final TextStyle heading3;
  static late final TextStyle bodyLarge;
  static late final TextStyle bodyMedium;
  static late final TextStyle bodySmall;
  static late final TextStyle labelMedium;
  static late final TextStyle labelSmall;

  // Input field styles
  static late final TextStyle inputText;
  static late final TextStyle inputHint;
  static late final TextStyle inputLabel;
  static late final TextStyle inputError;

  /// Call this method in main() before runApp()
  static Future<void> initialize() async {
    _baseStyle = GoogleFonts.poppins();

    // Headings
    heading1 = _baseStyle.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    heading2 = _baseStyle.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    heading3 = _baseStyle.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    // Body text
    bodyLarge = _baseStyle.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    );

    bodyMedium = _baseStyle.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Colors.white,
    );

    bodySmall = _baseStyle.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Colors.white70,
    );

    // Labels
    labelMedium = _baseStyle.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    labelSmall = _baseStyle.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    );

    // Input fields
    inputText = _baseStyle.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );

    inputHint = _baseStyle.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Colors.black.withOpacity(0.3),
    );

    inputLabel = _baseStyle.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    inputError = _baseStyle.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: const Color(0xFFCF6C79),
    );
  }

  /// Helper method to create text style with custom color
  static TextStyle withColor(TextStyle baseStyle, Color color) {
    return baseStyle.copyWith(color: color);
  }

  /// Helper method to create text style with custom size
  static TextStyle withSize(TextStyle baseStyle, double size) {
    return baseStyle.copyWith(fontSize: size);
  }

  /// Helper method to create text style with custom weight
  static TextStyle withWeight(TextStyle baseStyle, FontWeight weight) {
    return baseStyle.copyWith(fontWeight: weight);
  }
}
