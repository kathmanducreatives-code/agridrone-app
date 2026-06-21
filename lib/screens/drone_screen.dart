import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/dashboard_providers.dart';
import '../providers/flight_providers.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_ui.dart';
import 'test_ai_screen.dart';

class DroneScreen extends ConsumerWidget {
  const DroneScreen({super.key});

  static const _preFlight = [
    'Battery secured',
    'Propellers checked',
    'Camera facing crop',
    'SD card ready',
    'Field area clear',
    'Weather safe',
    'Drone calibrated',
    'Operator ready',
  ];

  static const _postFlight = [
    'Connect to Wi-Fi',
    'Upload images',
    'Review crop images',
    'Run crop health check',
    'Generate report',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveDetections = ref.watch(liveDetectionsProvider);
    final count60s = ref.watch(liveDetectionsLast60sCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Drone Activity',
                subtitle:
                    'Flight guidance mode for capturing crop images and turning them into farmer-ready decisions.',
                trailing: ElevatedButton.icon(
                  onPressed: () => _askAdvisor(ref,
                      'What should I check before starting a drone flight?'),
                  icon: const Icon(Icons.eco_rounded),
                  label: const Text('Ask AI Advisor'),
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1000;
                  final status = _FlightStatusCard(
                    liveCount: liveDetections.length,
                    count60s: count60s,
                  );
                  final latest = _LatestActivityCard(
                    hasLatest: liveDetections.isNotEmpty,
                    latestLabel: liveDetections.isNotEmpty
                        ? liveDetections.first.displayLabel
                        : 'No new crop image yet',
                    latestMeta: liveDetections.isNotEmpty
                        ? '${liveDetections.first.confidencePercent} confidence'
                        : 'Images will appear after upload or flight sync.',
                  );
                  if (!wide) {
                    return Column(
                      children: [
                        status,
                        const SizedBox(height: 16),
                        latest,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: status),
                      const SizedBox(width: 18),
                      Expanded(child: latest),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  final pre = _ChecklistCard(
                    title: 'Start Flight Checklist',
                    subtitle:
                        'Use this before flying. Direct flight control is not connected in this app yet.',
                    items: _preFlight,
                  );
                  final post = _ChecklistCard(
                    title: 'Post-Flight Checklist',
                    subtitle:
                        'Use this after landing to get images ready for crop health checking.',
                    items: _postFlight,
                  );
                  if (!wide) {
                    return Column(
                      children: [
                        pre,
                        const SizedBox(height: 16),
                        post,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: pre),
                      const SizedBox(width: 18),
                      Expanded(child: post),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _DroneActions(ref: ref),
            ],
          ),
        ),
      ),
    );
  }

  void _askAdvisor(WidgetRef ref, String prompt) {
    ref.read(globalAiAdvisorProvider.notifier).open();
    ref
        .read(globalAiAdvisorProvider.notifier)
        .sendMessage(prompt, ref.read(aiAdvisorAppContextProvider));
  }
}

class _FlightStatusCard extends StatelessWidget {
  final int liveCount;
  final int count60s;

  const _FlightStatusCard({
    required this.liveCount,
    required this.count60s,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            'Drone status',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Direct flight control is not connected. The app guides capture, upload, crop checking, and report creation.',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Images this session',
                  value: '$liveCount',
                  icon: Icons.photo_camera_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Recent checks',
                  value: '$count60s',
                  icon: Icons.health_and_safety_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _WeatherNotice(),
        ],
      ),
    );
  }
}

class _LatestActivityCard extends StatelessWidget {
  final bool hasLatest;
  final String latestLabel;
  final String latestMeta;

  const _LatestActivityCard({
    required this.hasLatest,
    required this.latestLabel,
    required this.latestMeta,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasLatest ? Icons.image_search_rounded : Icons.add_photo_alternate,
            color: AppColors.green,
            size: 30,
          ),
          const SizedBox(height: 14),
          Text(
            'Last image received',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latestLabel,
            style: GoogleFonts.spaceGrotesk(
              color: hasLatest ? AppColors.text : AppColors.textDim,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            latestMeta,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 13,
              height: 1.4,
            ),
          ),

        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> items;

  const _ChecklistCard({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map((item) => _ChecklistRow(item)),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;

  const _ChecklistRow(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.green.withAlpha(70)),
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.green, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DroneActions extends StatelessWidget {
  final WidgetRef ref;

  const _DroneActions({required this.ref});

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 26,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ElevatedButton.icon(
            onPressed: () => ref
                .read(globalAiAdvisorProvider.notifier)
                .sendMessage('Help me start the drone flight checklist',
                    ref.read(aiAdvisorAppContextProvider)),
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: const Text('Start Flight Checklist'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TestAiScreen()),
            ),
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text('Upload Flight Images'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(globalAiAdvisorProvider.notifier).open();
              ref.read(globalAiAdvisorProvider.notifier).sendMessage(
                    'What should I do after landing?',
                    ref.read(aiAdvisorAppContextProvider),
                  );
            },
            icon: const Icon(Icons.eco_rounded),
            label: const Text('Ask AI Advisor'),
          ),
          OutlinedButton.icon(
            onPressed: () => ref.read(currentTabProvider.notifier).set(3),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('View Latest Images'),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(190),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green, size: 19),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherNotice extends StatelessWidget {
  const _WeatherNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warn.withAlpha(16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warn.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_cloudy_outlined, color: AppColors.warn, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Local Weather: Weather not connected. Check field conditions before flying.',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
