import 'package:flutter/material.dart';

/// Central white/green agtech SaaS design system color tokens.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg = Color(0xFFF7FBF6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFEFF7EF);
  static const Color glass = Color.fromRGBO(255, 255, 255, 0.72);
  static const Color glassHi = Color.fromRGBO(255, 255, 255, 0.88);

  // Lines & dividers
  static const Color line = Color.fromRGBO(20, 83, 45, 0.12);
  static const Color line2 = Color.fromRGBO(20, 83, 45, 0.20);
  static const Color lineBright = Color.fromRGBO(22, 163, 74, 0.35);

  // Brand
  static const Color green = Color(0xFF16A34A);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color greenLime = Color(0xFFA3E635);
  static const Color greenDeep = Color(0xFF14532D);
  static const Color teal = Color(0xFF14B8A6);

  // Text
  static const Color text = Color(0xFF17231B);
  static const Color textDim = Color(0xFF66736B);
  static const Color textFaint = Color(0xFF93A39A);

  // Status
  static const Color warn = Color(0xFFF59E0B);
  static const Color crit = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);
  static const Color unknown = Color(0xFF94A3B8);

  // Curation States
  static const Color selected = Color(0xFFF59E0B);
  static const Color rejected = Color(0xFFDC2626);
  static const Color analyzed = Color(0xFF16A34A);

  // Disease class colors
  static const Map<String, Color> diseaseColors = {
    'Rice_Blast': Color(0xFFDC2626),
    'Brown_Spot': Color(0xFFF59E0B),
    'Narrow_Brown_Spot': Color(0xFFD97706),
    'Dirty_Panicle': Color(0xFF0EA5E9),
    'Brown Spot Disease': Color(0xFFF59E0B),
    'Rice Blast Disease': Color(0xFFDC2626),
    'Rice_Brown_spot': Color(0xFFF59E0B),
  };
}
