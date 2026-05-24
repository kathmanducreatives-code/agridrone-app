import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_dot.dart';
import '../providers/dashboard_providers.dart';
import '../providers/flight_providers.dart';
import '../providers/realtime_providers.dart';
import '../services/realtime_service.dart';
import 'login_screen.dart';

/// Settings and Diagnostic Console Screen displaying connection diagnostics, health checks, and metadata.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _testingSupabase = false;
  bool _testingFastApi = false;

  void _handleLogout() {
    ref.read(authStateProvider.notifier).logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _testSupabase() async {
    setState(() => _testingSupabase = true);
    try {
      await Supabase.instance.client
          .from('flight_captures')
          .select('id')
          .limit(1);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('SUPABASE OK', style: GoogleFonts.spaceGrotesk(color: AppColors.green, fontWeight: FontWeight.bold)),
            content: Text(
              'Successfully verified query against Supabase database. Captures check complete.',
              style: GoogleFonts.spaceGrotesk(color: AppColors.text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE', style: GoogleFonts.spaceGrotesk(color: AppColors.green)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('SUPABASE ERROR', style: GoogleFonts.spaceGrotesk(color: AppColors.crit, fontWeight: FontWeight.bold)),
            content: Text('Database verification query failed: $e', style: GoogleFonts.spaceGrotesk(color: AppColors.text)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE', style: GoogleFonts.spaceGrotesk(color: AppColors.crit)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingSupabase = false);
    }
  }

  Future<void> _testFastApi() async {
    setState(() => _testingFastApi = true);
    try {
      final health = await ref.read(huggingFaceServiceProvider).health();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('FASTAPI OK', style: GoogleFonts.spaceGrotesk(color: AppColors.green, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: health.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: GoogleFonts.jetBrainsMono(color: AppColors.text, fontSize: 13.0),
                  ),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE', style: GoogleFonts.spaceGrotesk(color: AppColors.green)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('FASTAPI ERROR', style: GoogleFonts.spaceGrotesk(color: AppColors.crit, fontWeight: FontWeight.bold)),
            content: Text('Inference space check failed: $e', style: GoogleFonts.spaceGrotesk(color: AppColors.text)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE', style: GoogleFonts.spaceGrotesk(color: AppColors.crit)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingFastApi = false);
    }
  }

  Future<void> _resubscribeRealtime() async {
    try {
      await ref.read(realtimeServiceProvider).reconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Curation Realtime channel re-initialized successfully'),
            backgroundColor: AppColors.greenDeep,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-subscribe failed: $e'),
            backgroundColor: AppColors.crit,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final connStateAsync = ref.watch(realtimeConnectionProvider);

    Color connectionColor = AppColors.crit;
    connStateAsync.whenData((state) {
      if (state == RealtimeConnectionState.connected) {
        connectionColor = AppColors.green;
      } else if (state == RealtimeConnectionState.connecting) {
        connectionColor = AppColors.warn;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'SYSTEM SETUP & METRICS',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 20.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16.0),

              // Operator Profile
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.green.withAlpha((255 * 0.1).toInt()),
                      child: const Icon(Icons.person, color: AppColors.green, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Curation Drone Operator',
                          style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.email ?? 'operator@agridrone.io',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textDim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Realtime Status bar
              GlassCard(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REALTIME METRIC SYNC STATUS',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        StatusDot(color: connectionColor, size: 8.0),
                        const SizedBox(width: 8.0),
                        Text(
                          connStateAsync.maybeWhen(
                            data: (state) => state.name.toUpperCase(),
                            orElse: () => 'CONNECTING',
                          ),
                          style: GoogleFonts.jetBrainsMono(color: connectionColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'SUPABASE INSTANCE SETTINGS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textFaint,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // API Fields
              GlassCard(
                child: Column(
                  children: [
                    _buildApiField('DATABASE REFERENCE URL', SupabaseConfig.url),
                    const Divider(color: AppColors.line, height: 24.0),
                    _buildApiField('ANON PUBLIC KEY ID', '${SupabaseConfig.anonKey.substring(0, 24)}••••••••'),
                    const Divider(color: AppColors.line, height: 24.0),
                    _buildApiField('STORAGE BUCKET TARGET', SupabaseConfig.storageBucket),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'FASTAPI MODEL SPACE SETTINGS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textFaint,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              GlassCard(
                child: Column(
                  children: [
                    _buildApiField('INFERENCE PREDICT ENDPOINT', SupabaseConfig.huggingFacePredictUrl),
                    const Divider(color: AppColors.line, height: 24.0),
                    _buildApiField('HEALTH DIAGNOSTICS ENDPOINT', SupabaseConfig.huggingFaceHealthUrl),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Diagnostic Actions Grid
              Text(
                'CURATION ACTIONS & DIAGNOSTICS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textFaint,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _testingSupabase
                        ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                        : OutlinedButton(
                            onPressed: _testSupabase,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.green,
                              side: const BorderSide(color: AppColors.lineBright),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            child: Text(
                              'TEST SUPABASE',
                              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12.0),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _testingFastApi
                        ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                        : OutlinedButton(
                            onPressed: _testFastApi,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.green,
                              side: const BorderSide(color: AppColors.lineBright),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            child: Text(
                              'TEST FASTAPI',
                              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12.0),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              ElevatedButton.icon(
                onPressed: _resubscribeRealtime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green.withAlpha((255 * 0.1).toInt()),
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.lineBright),
                  minimumSize: const Size.fromHeight(44.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                icon: const Icon(Icons.sync_problem, size: 16.0),
                label: Text(
                  'RE-SUBSCRIBE TO REALTIME',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12.0),
                ),
              ),
              const SizedBox(height: 32.0),

              // Academic About Block
              Center(
                child: Column(
                  children: [
                    Text(
                      'AgriDrone Guardian v2.4.0',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textDim, fontSize: 12.0, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'IoT + AI Curated Dashboard · CC4003NI',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textFaint, fontSize: 11.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // Logout Button
              OutlinedButton.icon(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.crit),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout_rounded, color: AppColors.crit, size: 18),
                label: Text(
                  'SIGN OUT OPERATOR ACCOUNT',
                  style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.crit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiField(String label, String value) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textFaint),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
