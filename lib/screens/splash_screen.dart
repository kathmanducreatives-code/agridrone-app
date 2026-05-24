import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

/// Splash screen that renders a pulsing cyber-agricultural seal for 1.8 seconds.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.green.withAlpha((255 * 0.05).toInt()),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.green.withAlpha((255 * _pulseAnimation.value * 0.25).toInt()),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withAlpha((255 * _pulseAnimation.value * 0.15).toInt()),
                          blurRadius: 20.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
              child: const Icon(
                Icons.hexagon_outlined,
                color: AppColors.green,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'AGRIDRONE GUARDIAN',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'CYBERNETIC IoT + AI CURATION',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textDim,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 64),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
