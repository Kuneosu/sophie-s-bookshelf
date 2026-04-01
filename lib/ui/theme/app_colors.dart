import 'package:flutter/material.dart';

class AppColors {
  // Primary - 따뜻한 브라운 (책/나무 느낌)
  static const Color primary = Color(0xFF6B4226);
  static const Color primaryLight = Color(0xFF8B6340);
  static const Color primaryDark = Color(0xFF4A2E1A);

  // Secondary - 크림 (종이 느낌)
  static const Color cream = Color(0xFFE8D5B7);
  static const Color creamLight = Color(0xFFF5EDE0);

  // Background
  static const Color background = Color(0xFFFAFAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F0EB);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFFB0A89E);

  // Accent
  static const Color accent = Color(0xFFD4853A);

  // Status colors
  static const Color wantToRead = Color(0xFF7BA5C9);   // 부드러운 블루
  static const Color reading = Color(0xFFD4853A);       // 오렌지-브라운
  static const Color finished = Color(0xFF7BAF6E);      // 부드러운 그린
  static const Color dropped = Color(0xFFB0A89E);       // 그레이

  // Dark Mode
  static const Color darkBackground = Color(0xFF1A1612);
  static const Color darkSurface = Color(0xFF2D2520);
  static const Color darkSurfaceVariant = Color(0xFF3D3530);
  static const Color darkTextPrimary = Color(0xFFF0E8E0);
  static const Color darkTextSecondary = Color(0xFFB0A89E);

  static Color statusColor(int statusIndex) {
    switch (statusIndex) {
      case 0: return wantToRead;
      case 1: return reading;
      case 2: return finished;
      case 3: return dropped;
      default: return textHint;
    }
  }
}
