import 'package:flutter/material.dart';

/// Central white/green agtech SaaS design system color tokens.
///
/// Premium green agriculture palette: deep leaf green, paddy green,
/// soft mint, warm cream, soil brown — balanced for a polished SaaS feel.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg = Color(0xFFF8F4EA); // Warm cream
  static const Color surface = Color(0xFFFCFBF7); // Soft off-white surface
  static const Color surface2 = Color(0xFFF4EDE2); // Soft clay-toned cream surface
  static const Color glass = Color.fromRGBO(252, 251, 247, 0.72);
  static const Color glassHi = Color.fromRGBO(252, 251, 247, 0.88);

  // Lines & dividers
  static const Color line = Color.fromRGBO(110, 95, 82, 0.12); // Earth line
  static const Color line2 = Color.fromRGBO(110, 95, 82, 0.20);
  static const Color lineBright = Color.fromRGBO(176, 125, 98, 0.35); // Soft terracotta border

  // Brand
  static const Color green = Color(0xFF1F6B4A); // Deep leaf green (primary)
  static const Color greenSoft = Color(0xFF4FAF73); // Fresh paddy green
  static const Color greenLime = Color(0xFFDFF4E8); // Soft mint
  static const Color greenDeep = Color(0xFF14532D); // Dark soil green
  static const Color teal = Color(0xFFA97955); // Warm soil brown accent

  // Accent
  static const Color sunlight = Color(0xFFF5D77A); // Soft yellow sunlight
  static const Color rainyBlue = Color(0xFFDDEBEA); // Light rainy blue-gray

  // Text
  static const Color text = Color(0xFF2B2118); // Dark clay soil text
  static const Color textDim = Color(0xFF6E5F52); // Soft earth brown text
  static const Color textFaint = Color(0xFF9C8E82); // Faint dust brown text

  // Status
  static const Color warn = Color(0xFFE9C46A); // Warm mustard yellow
  static const Color crit = Color(0xFFC94A29); // Warm red clay
  static const Color info = Color(0xFF4A90E2);
  static const Color unknown = Color(0xFF9C8E82);

  // Curation States
  static const Color selected = Color(0xFFE9C46A);
  static const Color rejected = Color(0xFFC94A29);
  static const Color analyzed = Color(0xFF1F6B4A);

  // Disease class colors
  static const Map<String, Color> diseaseColors = {
    'Rice_Blast': Color(0xFFC94A29),
    'Brown_Spot': Color(0xFFE9C46A),
    'Narrow_Brown_Spot': Color(0xFFD68C45),
    'Dirty_Panicle': Color(0xFF4A90E2),
    'Brown Spot Disease': Color(0xFFE9C46A),
    'Rice Blast Disease': Color(0xFFC94A29),
    'Rice_Brown_spot': Color(0xFFE9C46A),
    'Gabaro': Color(0xFFC94A29),
    'Rice Stem Borer': Color(0xFFC94A29),
    'Khaira Disease': Color(0xFFE9C46A),
  };
}
