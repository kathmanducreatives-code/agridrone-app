import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../providers/dashboard_providers.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/farmer_profile_provider.dart';
import '../providers/flight_providers.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../providers/realtime_providers.dart';
import '../services/realtime_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _testingCloud = false;
  bool _testingImageAnalysis = false;
  late final TextEditingController _farmNameController;
  late final TextEditingController _operatorNameController;
  late final TextEditingController _cropTypeController;
  late final TextEditingController _fieldNameController;
  late final TextEditingController _cropStageController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _farmNameController = TextEditingController();
    _operatorNameController = TextEditingController();
    _cropTypeController = TextEditingController();
    _fieldNameController = TextEditingController();
    _cropStageController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _operatorNameController.dispose();
    _cropTypeController.dispose();
    _fieldNameController.dispose();
    _cropStageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    ref.read(authStateProvider.notifier).logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _testCloudSync() async {
    setState(() => _testingCloud = true);
    try {
      await Supabase.instance.client
          .from('flight_captures')
          .select('id')
          .limit(1);
      if (mounted) {
        _showStatusDialog(
          title: 'Cloud Sync Ready',
          body: 'Cloud image records can be checked successfully.',
          ok: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showStatusDialog(
          title: 'Cloud Sync Needs Attention',
          body:
              'The app could not verify cloud image records. You can still use demo mode.',
          ok: false,
        );
      }
    } finally {
      if (mounted) setState(() => _testingCloud = false);
    }
  }

  Future<void> _testImageAnalysis() async {
    setState(() => _testingImageAnalysis = true);
    try {
      await ref.read(huggingFaceServiceProvider).health();
      if (mounted) {
        _showStatusDialog(
          title: 'Image Analysis Ready',
          body: 'Crop image checking is ready for the current demo.',
          ok: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showStatusDialog(
          title: 'Image Analysis Needs Attention',
          body:
              'The crop image checker is not responding. Use demo mode or restart the local analysis service.',
          ok: false,
        );
      }
    } finally {
      if (mounted) setState(() => _testingImageAnalysis = false);
    }
  }

  Future<void> _reconnectAppSync() async {
    try {
      await ref.read(realtimeServiceProvider).reconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App sync reconnected.'),
            backgroundColor: AppColors.greenDeep,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App sync needs attention.'),
            backgroundColor: AppColors.crit,
          ),
        );
      }
    }
  }

  void _showStatusDialog({
    required String title,
    required String body,
    required bool ok,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: ok ? AppColors.green : AppColors.crit,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          body,
          style: GoogleFonts.spaceGrotesk(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.spaceGrotesk(
                color: ok ? AppColors.green : AppColors.crit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final demoMode = ref.watch(demoModeProvider);
    final profile = ref.watch(farmerProfileProvider);
    final syncState = ref.watch(realtimeConnectionProvider);

    _syncProfileControllers(profile);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Settings',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage farm preferences, demo mode, and optional connection checks.',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.green.withAlpha(24),
                      child: const Icon(Icons.person_rounded,
                          color: AppColors.green),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.operatorName.trim().isNotEmpty
                                ? profile.operatorName.trim()
                                : 'AgriDrone Farmer',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            auth.email ?? 'operator@agridrone.io',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    _PreferenceRow(
                      icon: Icons.grass_rounded,
                      label: 'Farm name',
                      controller: _farmNameController,
                      hint: 'North Farm',
                      onChanged: (value) => _updateProfile(
                        profile.copyWith(farmName: value),
                      ),
                      onHelp: () => _askAdvisor(
                        'What is a good farm name to use in this app?',
                      ),
                    ),
                    const Divider(color: AppColors.line, height: 24),
                    _PreferenceRow(
                      icon: Icons.person_rounded,
                      label: 'Farmer or operator',
                      controller: _operatorNameController,
                      hint: 'Your name',
                      onChanged: (value) => _updateProfile(
                        profile.copyWith(operatorName: value),
                      ),
                      onHelp: () => _askAdvisor(
                        'What should I enter for farmer or operator name?',
                      ),
                    ),
                    const Divider(color: AppColors.line, height: 24),
                    _PreferenceRow(
                      icon: Icons.rice_bowl_rounded,
                      label: 'Crop type',
                      controller: _cropTypeController,
                      hint: 'Rice, wheat, or maize',
                      onChanged: (value) => _updateProfile(
                        profile.copyWith(cropType: value),
                      ),
                      onHelp: () => _askAdvisor(
                        'Help me choose crop type. What should I enter for rice, wheat, or maize?',
                      ),
                    ),
                    const Divider(color: AppColors.line, height: 24),
                    _PreferenceRow(
                      icon: Icons.location_on_rounded,
                      label: 'Field name',
                      controller: _fieldNameController,
                      hint: 'North Field or Rice Plot 1',
                      onChanged: (value) => _updateProfile(
                        profile.copyWith(fieldName: value),
                      ),
                      onHelp: () => _askAdvisor(
                        'What is a simple field name farmers can understand?',
                      ),
                    ),
                    const Divider(color: AppColors.line, height: 24),
                    _LanguageRow(
                      value: profile.language,
                      onChanged: (value) => _updateProfile(
                        profile.copyWith(language: value),
                      ),
                      onHelp: () => _askAdvisor(
                        'Explain the language setting in simple farmer language.',
                      ),
                    ),
                    const Divider(color: AppColors.line, height: 24),
                    _PreferenceRow(
                      icon: Icons.spa_rounded,
                      label: 'Crop stage',
                      controller: _cropStageController,
                      hint: 'Seedling, flowering, harvest',
                      onChanged: (value) => _updateProfile(
                        profile.copyWith(cropStage: value),
                      ),
                      onHelp: () => _askAdvisor(
                        'What does crop stage mean, and what should I enter?',
                      ),
                    ),
                    const Divider(color: AppColors.line, height: 24),
                    _PreferenceRow(
                      icon: Icons.notes_rounded,
                      label: 'Notes',
                      controller: _notesController,
                      hint: 'Anything important about this field',
                      onChanged: (value) => _updateProfile(
                        profile.copyWith(notes: value),
                      ),
                      onHelp: () => _askAdvisor(
                        'Help me write useful field notes for crop advice.',
                      ),
                    ),
                    const Divider(color: AppColors.line, height: 24),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: AppColors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Demo Preview',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: demoMode,
                          activeThumbColor: AppColors.green,
                          activeTrackColor: AppColors.green.withAlpha(70),
                          onChanged: (value) => ref
                              .read(demoModeProvider.notifier)
                              .setEnabled(value),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        demoMode
                            ? demoPreviewLabel
                            : 'Live farm data will be used when available.',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.textDim,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  iconColor: AppColors.green,
                  collapsedIconColor: AppColors.textDim,
                  title: Text(
                    'Advanced Diagnostics',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    'Optional connection checks for demo operators.',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                  children: [
                    _DiagnosticRow(
                      label: 'Cloud Sync',
                      value: _masked(SupabaseConfig.url),
                    ),
                    const Divider(color: AppColors.line, height: 22),
                    _DiagnosticRow(
                      label: 'Image AI',
                      value: _masked(SupabaseConfig.huggingFacePredictUrl),
                    ),
                    const Divider(color: AppColors.line, height: 22),
                    _DiagnosticRow(
                      label: 'AI Advisor',
                      value: _masked(SupabaseConfig.aiAssistantBaseUrl),
                    ),
                    const Divider(color: AppColors.line, height: 22),
                    _DiagnosticRow(
                      label: 'App Sync',
                      value: syncState.maybeWhen(
                        data: _syncLabel,
                        orElse: () => 'Getting ready',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _testingCloud ? null : _testCloudSync,
                          icon: _testingCloud
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.green,
                                  ),
                                )
                              : const Icon(Icons.cloud_done_rounded),
                          label: const Text('Test Cloud Sync'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _testingImageAnalysis ? null : _testImageAnalysis,
                          icon: _testingImageAnalysis
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.green,
                                  ),
                                )
                              : const Icon(Icons.image_search_rounded),
                          label: const Text('Test Image Analysis'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _reconnectAppSync,
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Reconnect App Sync'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.crit),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.crit, size: 18),
                label: Text(
                  'Sign Out',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.crit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _syncLabel(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return 'Ready';
      case RealtimeConnectionState.connecting:
        return 'Getting ready';
      case RealtimeConnectionState.disconnected:
        return 'Offline mode';
      case RealtimeConnectionState.error:
        return 'Needs attention';
    }
  }

  String _masked(String value) {
    if (value.length <= 18) return '••••••••';
    return '${value.substring(0, 10)}••••${value.substring(value.length - 4)}';
  }

  void _askAdvisor(String prompt) {
    ref.read(globalAiAdvisorProvider.notifier).open();
    ref.read(globalAiAdvisorProvider.notifier).sendMessage(
          prompt,
          ref.read(aiAdvisorAppContextProvider),
          language: ref.read(farmerProfileProvider).language,
        );
  }

  void _updateProfile(FarmerProfile profile) {
    ref.read(farmerProfileProvider.notifier).update(profile);
  }

  void _syncProfileControllers(FarmerProfile profile) {
    _setControllerText(_farmNameController, profile.farmName);
    _setControllerText(_operatorNameController, profile.operatorName);
    _setControllerText(_cropTypeController, profile.cropType);
    _setControllerText(_fieldNameController, profile.fieldName);
    _setControllerText(_cropStageController, profile.cropStage);
    _setControllerText(_notesController, profile.notes);
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onHelp;

  const _PreferenceRow({
    required this.icon,
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          width: 250,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textAlign: TextAlign.right,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              border: InputBorder.none,
              hintStyle: GoogleFonts.spaceGrotesk(
                color: AppColors.textFaint,
                fontSize: 12,
              ),
            ),
          ),
        ),
        if (onHelp != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ask AI Advisor',
            onPressed: onHelp,
            icon:
                const Icon(Icons.help_outline_rounded, color: AppColors.green),
          ),
        ],
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onHelp;

  const _LanguageRow({
    required this.value,
    required this.onChanged,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.language_rounded, color: AppColors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Language',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: AppColors.surface,
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ne', child: Text('Nepali ready')),
              DropdownMenuItem(value: 'hi', child: Text('Hindi ready')),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
        if (onHelp != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ask AI Advisor',
            onPressed: onHelp,
            icon:
                const Icon(Icons.help_outline_rounded, color: AppColors.green),
          ),
        ],
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;

  const _DiagnosticRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.textDim,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
