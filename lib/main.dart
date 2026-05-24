import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'theme/app_colors.dart';
import 'providers/realtime_providers.dart';
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

  runApp(
    const ProviderScope(
      child: AppStartupWidget(),
    ),
  );
}

/// Eagerly boots the Supabase Realtime channel subscription stream before main UI starts.
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches the singleton provider to boot and subscribe the channels instantly
    ref.watch(realtimeServiceProvider);

    return const AgriDroneApp();
  }
}

// ── Theme ──────────────────────────────────────────────────────

class AgriDroneTheme {
  AgriDroneTheme._();

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.green,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.green,
        surface: AppColors.surface,
        error: AppColors.crit,
        onPrimary: Colors.black,
        onSurface: AppColors.text,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            fontSize: 32,
            letterSpacing: -0.5),
        displayMedium: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            fontSize: 26,
            letterSpacing: -0.5),
        displaySmall: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            fontSize: 20,
            letterSpacing: -0.5),
        headlineMedium: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 18),
        headlineSmall: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 16),
        titleLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            color: AppColors.text,
            fontSize: 15,
            letterSpacing: 0.2),
        bodyLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w500, color: AppColors.text, fontSize: 16),
        bodyMedium: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w400,
            color: AppColors.text,
            fontSize: 14,
            letterSpacing: 0.1),
        bodySmall: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w400,
            color: AppColors.textDim,
            fontSize: 12,
            letterSpacing: 0.1),
        labelLarge: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w500,
            color: AppColors.text,
            fontSize: 15,
            letterSpacing: 0.5),
        labelMedium: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w400,
            color: AppColors.text,
            fontSize: 13,
            letterSpacing: 0.5),
        labelSmall: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w500,
            color: AppColors.textDim,
            fontSize: 10,
            letterSpacing: 0.5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.text),
      ),
    );
  }
}

// ── App Entry ──────────────────────────────────────────────────

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
