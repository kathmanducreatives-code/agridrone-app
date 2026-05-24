import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import 'main_navigation_screen.dart';

/// Single-tenant operator sign-in screen designed in a dark cyber aesthetic.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'operator@agridrone.io');
  final _passwordCtrl = TextEditingController(text: 'securepass123');
  bool _obscureText = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ref.read(authStateProvider.notifier).login(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Header Block
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.green.withAlpha((255 * 0.05).toInt()),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.green.withAlpha((255 * 0.15).toInt()),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.hexagon_outlined,
                        color: AppColors.green,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AGRIDRONE GUARDIAN',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Operator console — single tenant prototype',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Login Form wrapped in Glassmorphism Card
              GlassCard(
                bright: false,
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email Field Label
                      Text(
                        'Email Address',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        style: GoogleFonts.jetBrainsMono(color: AppColors.text, fontSize: 14),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'operator@agridrone.io',
                          hintStyle: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.textFaint),
                          prefixIcon: const Icon(Icons.mail_outline, size: 20, color: AppColors.textDim),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.green, width: 1.5),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.crit),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.crit, width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your email';
                          if (!v.contains('@')) return 'Please enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password Field Label
                      Text(
                        'Password',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordCtrl,
                        style: GoogleFonts.jetBrainsMono(color: AppColors.text, fontSize: 14),
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.textFaint),
                          prefixIcon: const Icon(Icons.lock_outlined, size: 20, color: AppColors.textDim),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppColors.textDim,
                            ),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.green, width: 1.5),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.crit),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.crit, width: 1.5),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your password';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'SIGN IN',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
