# AgriDrone Guardian - Flutter Project Info

This document provides a summary of the current Flutter project structure, dependencies, Supabase connection configurations, and active UI screens.

---

## 1. Project Directory Structure

```text
lib/
├── config/
│   └── supabase_config.dart
├── models/
│   ├── detection_item.dart
│   ├── device_alert.dart
│   ├── drone_telemetry.dart
│   ├── flight_capture.dart
│   └── flight_group.dart
├── providers/
│   ├── dashboard_providers.dart
│   └── flight_providers.dart
├── screens/
│   ├── alerts_screen.dart
│   ├── analytics_screen.dart
│   ├── dashboard_screen.dart
│   ├── drone_screen.dart
│   ├── login_screen.dart
│   ├── main_navigation_screen.dart
│   ├── settings_screen.dart
│   └── splash_screen.dart
├── services/
│   ├── huggingface_service.dart
│   └── supabase_service.dart
└── main.dart
```

---

## 2. pubspec.yaml

```yaml
name: agridrone_guardian
description: AgriDrone Guardian — crop disease monitoring dashboard
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  # ── Core ────────────────────────────────────────────────────
  supabase_flutter: ^2.12.4
  flutter_riverpod: ^3.3.1
  http: ^1.2.1
  # ── UI & Media ──────────────────────────────────────────────
  google_fonts: ^6.2.1
  cached_network_image: ^3.4.1
  fl_chart: ^0.69.0
  flutter_map: ^8.2.2
  latlong2: ^0.9.1
  # ── Utilities ───────────────────────────────────────────────
  intl: ^0.19.0
  shared_preferences: ^2.2.3
  file_picker: ^8.1.2
  pdf: ^3.12.0
  image_gallery_saver: ^2.0.3
  path_provider: ^2.1.5
  webview_flutter: ^4.13.1
  url_launcher: ^6.3.2

dev_dependencies:
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

---

## 3. main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait on mobile.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: AgriDroneApp()));
}

// ── Theme ──────────────────────────────────────────────────────

class AgriDroneTheme {
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color primaryAccent = Color(0xFF16A34A); // Green 600
  static const Color warning = Color(0xFFEAB308); // Yellow 500
  static const Color danger = Color(0xFFEF4444); // Red 500
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color borderHighlight = Color(0xFFE2E8F0); // Slate 200

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAccent,
      colorScheme: const ColorScheme.light(
        primary: primaryAccent,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: textPrimary,
            fontSize: 32,
            letterSpacing: -0.5),
        displayMedium: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: textPrimary,
            fontSize: 26,
            letterSpacing: -0.5),
        displaySmall: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: textPrimary,
            fontSize: 20,
            letterSpacing: -0.5),
        headlineMedium: GoogleFonts.inter(
            fontWeight: FontWeight.w700, color: textPrimary, fontSize: 18),
        headlineSmall: GoogleFonts.inter(
            fontWeight: FontWeight.w600, color: textPrimary, fontSize: 16),
        titleLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: textPrimary,
            fontSize: 15,
            letterSpacing: 0.2),
        bodyLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w500, color: textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            color: textPrimary,
            fontSize: 14,
            letterSpacing: 0.1),
        bodySmall: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            color: textSecondary,
            fontSize: 12,
            letterSpacing: 0.1),
        labelLarge: GoogleFonts.dmMono(
            fontWeight: FontWeight.w500,
            color: textPrimary,
            fontSize: 15,
            letterSpacing: 0.5),
        labelMedium: GoogleFonts.dmMono(
            fontWeight: FontWeight.w400,
            color: textPrimary,
            fontSize: 13,
            letterSpacing: 0.5),
        labelSmall: GoogleFonts.dmMono(
            fontWeight: FontWeight.w500,
            color: textSecondary,
            fontSize: 10,
            letterSpacing: 0.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: textPrimary,
        ),
      ),
    );
  }
}

// ── App ────────────────────────────────────────────────────────

class AgriDroneApp extends StatelessWidget {
  const AgriDroneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgriDrone Guardian',
      theme: AgriDroneTheme.themeData,
      home: const SplashScreen(),
    );
  }
}
```

---

## 4. Supabase Connection Configuration

The application initializes Supabase inside `main.dart` with the values defined in `lib/config/supabase_config.dart`.

### **`lib/config/supabase_config.dart`**
```dart
class SupabaseConfig {
  SupabaseConfig._();

  // ── Supabase ───────────────────────────────────────────────
  static const String url = 'https://luvostyizefajbltukkc.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1dm9zdHlpemVmYWpibHR1a2tjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxMDA1NDgsImV4cCI6MjA5MjY3NjU0OH0.FcihW48l30A7sxv5IC5GdekKCNTmFo2xEnAebBen5UI';
  static const String storageBucket = 'drone-images';

  // ── HuggingFace FastAPI ────────────────────────────────────
  static const String huggingFaceBaseUrl = 'https://YOUR_SPACE.hf.space';
  static const String huggingFaceWebhookPath = '/webhook/new_flight';
  static const String huggingFaceToken = 'YOUR_HF_BEARER_TOKEN';

  static String get huggingFaceWebhookUrl =>
      '$huggingFaceBaseUrl$huggingFaceWebhookPath';
}
```

---

## 5. Active Screens and Layout

The application has been streamlined using a `BottomNavigationBar` configuration inside `lib/screens/main_navigation_screen.dart`.

- **`SplashScreen`**: Initial logo animation; routes to the login view after 1.8 seconds.
- **`LoginScreen`**: Simple, minimal email/password form for Operator authentication.
- **`DashboardScreen`**: Overview displaying connection status, KPI metrics (total scans, detections, crop health %), a list of recent detections, and weekly scan volume charts.
- **`DroneScreen`**: Displays detailed telemetry, battery indicators, WiFi signals, GPS coordinates, and synchronization progress.
- **`AnalyticsScreen`**: Shows health distribution percentages and disease species distributions.
- **`AlertsScreen`**: Lists categorized notifications warnings.
- **`SettingsScreen`**: Toggles notification preferences, theme toggles, and displays current Supabase API connection parameters.
