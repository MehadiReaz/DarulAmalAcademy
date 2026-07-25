import 'package:flutter/material.dart';

/// Palette from the approved design (deep teal + gold).
class AppColors {
  AppColors._();

  static const Color bgDeep = Color(0xFF0C221F);
  static const Color bgTeal = Color(0xFF12302C);
  static const Color surface = Color(0xFF193B36);
  static const Color surfaceAlt = Color(0xFF1E433D);
  static const Color line = Color(0xFF274C46);

  static const Color gold = Color(0xFFEFA836);
  static const Color goldLight = Color(0xFFF6C566);
  static const Color goldDeep = Color(0xFFE0952A);

  static const Color cream = Color(0xFFF4EFE2);
  static const Color muted = Color(0xFF8CA6A0);

  static const Color navAccent = Color(0xFFEFA836);
  static const Color navInactive = Color(0xFF8CA6A0);

  static const Color success = Color(0xFF4FB286);
  static const Color danger = Color(0xFFE07A6B);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, goldDeep],
  );
}
