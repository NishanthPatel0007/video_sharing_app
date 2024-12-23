import 'package:flutter/material.dart';

class ThemeConstants {
  // Base Colors
  static const deepPurple = Color(0xFF1E1633);
  static const cardPurple = Color(0xFF2A2141);
  static const brightPurple = Color(0xFF8257E5);
  static const lavender = Color(0xFFE1E1E6);
  
  // Text Colors
  static const textWhite = Colors.white;
  static const textGrey = Color(0xFFC4C4CC);
  
  // Progress Colors
  static const progressActive = brightPurple;
  static const progressInactive = Color(0xFF2A2141);
  
  // Gradients
  static const purpleGradient = LinearGradient(
    colors: [brightPurple, Color(0xFF633BBC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card Decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardPurple,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Text Styles
  static const titleStyle = TextStyle(
    color: textWhite,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const subtitleStyle = TextStyle(
    color: textWhite,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const bodyStyle = TextStyle(
    color: textGrey,
    fontSize: 14,
  );

  // Milestone Circle Styles
  static const double circleSizeNormal = 40.0;
  static const double circleSizeLarge = 48.0;
  
  // Animation Durations
  static const Duration fadeAnimationDuration = Duration(milliseconds: 300);
  static const Duration scrollAnimationDuration = Duration(milliseconds: 500);
}