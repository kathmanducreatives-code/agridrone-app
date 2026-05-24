import 'package:flutter/material.dart';

/// Central dark cyber-agri design system color tokens.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg          = Color(0xFF000000);   // pitch black
  static const Color surface     = Color(0xFF0A0F0A);   // near black
  static const Color surface2    = Color(0xFF0D130D);
  static const Color glass       = Color.fromRGBO(15, 25, 18, 0.42);
  static const Color glassHi     = Color.fromRGBO(20, 35, 25, 0.62);

  // Lines & dividers
  static const Color line        = Color.fromRGBO(0, 255, 136, 0.10);
  static const Color line2       = Color.fromRGBO(0, 255, 136, 0.20);
  static const Color lineBright  = Color.fromRGBO(0, 255, 136, 0.45);

  // Brand
  static const Color green       = Color(0xFF00FF88);   // Neon Green
  static const Color greenSoft   = Color(0xFF00D4AA);
  static const Color greenLime   = Color(0xFFAAFF00);
  static const Color greenDeep   = Color(0xFF007A40);

  // Text
  static const Color text        = Color(0xFFE7F5E9);
  static const Color textDim     = Color(0xFF8AA896);
  static const Color textFaint   = Color(0xFF557066);

  // Status
  static const Color warn        = Color(0xFFFFB547);
  static const Color crit        = Color(0xFFFF5577);
  static const Color info        = Color(0xFF5AD7FF);

  // Curation States
  static const Color selected    = Color(0xFFFFD700);   // gold border
  static const Color rejected    = Color(0xFFFF5577);   // red dim
  static const Color analyzed    = Color(0xFF00FF88);   // green check

  // Disease class colors
  static const Map<String, Color> diseaseColors = {
    'Rice_Blast':        Color(0xFFFF5577),
    'Brown_Spot':        Color(0xFFFFB547),
    'Narrow_Brown_Spot': Color(0xFFFFD700),
    'Dirty_Panicle':     Color(0xFF5AD7FF),
  };
}
