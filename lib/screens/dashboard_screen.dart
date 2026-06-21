import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/campaign_view.dart';
import '../models/flight_capture.dart';
import '../models/flight_summary.dart';
import '../providers/campaign_providers.dart';
import '../providers/dashboard_providers.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/farmer_profile_provider.dart';
import '../providers/flight_providers.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../providers/map_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_ui.dart';
import '../widgets/farmer_mascot.dart';
import '../widgets/asset_illustrations.dart';
import 'test_ai_screen.dart';

enum DashboardWeatherState { notConnected, connected }

final dashboardWeatherProvider = Provider<DashboardWeatherState>((ref) {
  return DashboardWeatherState.notConnected;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(farmerProfileProvider);
    final demoMode = ref.watch(demoModeProvider);
    final campaigns = ref.watch(flightCampaignsProvider);
    final flights = ref.watch(allFlightsProvider);
    final latestFlight = ref.watch(latestFlightSummaryProvider);
    final captures = ref.watch(allFlightCapturesProvider);
    final pendingCount = ref.watch(pendingReviewCountProvider);
    final analyzedToday = ref.watch(analyzedTodayCountProvider);
    final detectionsToday = ref.watch(todayDetectionsCountProvider);
    final pathPoints = ref.watch(flightPathPointsProvider);
    final weatherState = ref.watch(dashboardWeatherProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GreetingHero(
                profile: profile,
                latestFlight: latestFlight,
                weatherState: weatherState,
                onCheckCrop: () => _openCheckCrop(context),
                onAskAi: () => _openAdvisor(ref),
              ),
              if (demoMode) ...[
                const SizedBox(height: 16),
                const _DemoNotice(),
              ],
              const SizedBox(height: 22),
              _FarmSnapshotGrid(
                campaigns: campaigns,
                flights: flights,
                latestFlight: latestFlight,
                captures: captures,
                pendingCount: pendingCount,
                analyzedToday: analyzedToday,
                detectionsToday: detectionsToday,
                pathPoints: pathPoints,
                weatherState: weatherState,
              ),
              const SizedBox(height: 22),
              _RecommendedActionsSection(
                onReviewImages: () =>
                    ref.read(currentTabProvider.notifier).set(3),
                onPlanFlight: () =>
                    _sendDashboardPrompt(ref, 'Help me plan a drone flight'),
                onCreateReport: () =>
                    ref.read(currentTabProvider.notifier).set(6),
                onConfigureCrop: () =>
                    ref.read(currentTabProvider.notifier).set(8),
              ),
              const SizedBox(height: 22),
              _CropHealthSummaryCard(
                captures: captures,
                detectionsToday: detectionsToday,
                onViewImages: () =>
                    ref.read(currentTabProvider.notifier).set(3),
                onAskAi: (prompt) => _sendDashboardPrompt(ref, prompt),
                onUpload: () => _openCheckCrop(context),
              ),
              const SizedBox(height: 22),
              _CampaignsFlightsSection(
                campaigns: campaigns,
                flights: flights,
                geotaggedFlightIds: pathPoints.maybeWhen(
                  data: (points) => points.map((p) => p.flightId).toSet(),
                  orElse: () => const <int>{},
                ),
                onOpenCampaigns: () =>
                    ref.read(currentTabProvider.notifier).set(2),
                onAddImages: () => _openCheckCrop(context),
                onAskAi: (prompt) => _sendDashboardPrompt(ref, prompt),
                onViewMap: () => ref.read(currentTabProvider.notifier).set(5),
                onCreateReport: () =>
                    ref.read(currentTabProvider.notifier).set(6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCheckCrop(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TestAiScreen()),
    );
  }

  void _openAdvisor(WidgetRef ref) {
    ref.read(globalAiAdvisorProvider.notifier).open();
  }

  void _sendDashboardPrompt(WidgetRef ref, String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    ref.read(globalAiAdvisorProvider.notifier).sendMessage(
          text,
          ref.read(aiAdvisorAppContextProvider),
          language: ref.read(farmerProfileProvider).language,
        );
  }
}

class _GreetingHero extends StatelessWidget {
  final FarmerProfile profile;
  final AsyncValue<FlightSummary?> latestFlight;
  final DashboardWeatherState weatherState;
  final VoidCallback onCheckCrop;
  final VoidCallback onAskAi;

  const _GreetingHero({
    required this.profile,
    required this.latestFlight,
    required this.weatherState,
    required this.onCheckCrop,
    required this.onAskAi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDeep.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                AppAssets.dashboardHero,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                      color: AppColors.greenDeep.withValues(alpha: 0.2));
                },
              ),
            ),
            // Glassmorphic Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surface.withValues(alpha: 0.92),
                      AppColors.surface.withValues(alpha: 0.75),
                      AppColors.greenDeep.withValues(alpha: 0.25),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Namaste, Kisan Dai/Didi',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontSize: wide ? 36 : 28,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your AI-powered crop health dashboard',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.greenDeep,
                          fontSize: wide ? 20 : 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Check today’s weather, review crop health, track drone flights, and get simple AI recommendations for your field.',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.textDim,
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Weather simple badge inside Hero
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.teal.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.teal.withAlpha(60)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    color: AppColors.teal, size: 13),
                                const SizedBox(width: 6),
                                Text(
                                  'असार · Paddy Season',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppColors.teal,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.green.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.green.withAlpha(60)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_queue_rounded,
                                    color: AppColors.green, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  weatherState ==
                                          DashboardWeatherState.connected
                                      ? 'Jhapa, Terai · 28°C · Rainy'
                                      : 'Weather unavailable',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppColors.greenDeep,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                  final actions = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FarmerMascot(size: 110, animate: true),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: onAskAi,
                            icon: const Icon(Icons.eco_rounded, size: 16),
                            label: const Text('Ask AI Advisor'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onCheckCrop,
                            icon: const Icon(Icons.add_photo_alternate_rounded,
                                size: 16),
                            label: const Text('Check Crop Image'),
                          ),
                        ],
                      ),
                    ],
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: copy),
                                const SizedBox(width: 28),
                                actions,
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                copy,
                                const SizedBox(height: 20),
                                Center(child: actions),
                              ],
                            ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;
  final Color color;

  const _RecommendedActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    this.color = AppColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      borderColor: AppColors.lineBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedActionsSection extends StatelessWidget {
  final VoidCallback onReviewImages;
  final VoidCallback onPlanFlight;
  final VoidCallback onCreateReport;
  final VoidCallback onConfigureCrop;

  const _RecommendedActionsSection({
    required this.onReviewImages,
    required this.onPlanFlight,
    required this.onCreateReport,
    required this.onConfigureCrop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Recommended Actions',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 960
                ? 4
                : (constraints.maxWidth >= 600 ? 2 : 1);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio:
                  columns == 4 ? 1.15 : (columns == 2 ? 1.5 : 1.8),
              children: [
                _RecommendedActionCard(
                  icon: Icons.photo_library_rounded,
                  title: 'Review crop images',
                  description:
                      'Inspect drone pictures for possible pest or disease spots.',
                  actionLabel: 'Review Images',
                  onPressed: onReviewImages,
                  color: AppColors.green,
                ),
                _RecommendedActionCard(
                  icon: Icons.flight_takeoff_rounded,
                  title: 'Plan drone flight',
                  description:
                      'Check conditions and prepare the drone path checklist.',
                  actionLabel: 'Plan Flight',
                  onPressed: onPlanFlight,
                  color: AppColors.teal,
                ),
                _RecommendedActionCard(
                  icon: Icons.description_rounded,
                  title: 'Generate crop report',
                  description:
                      'Create a PDF summary report of current disease findings.',
                  actionLabel: 'Create Report',
                  onPressed: onCreateReport,
                  color: AppColors.green,
                ),
                _RecommendedActionCard(
                  icon: Icons.settings_rounded,
                  title: 'Configure crop type',
                  description:
                      'Add crop parameters to get personalized AI advice.',
                  actionLabel: 'Configure Crop',
                  onPressed: onConfigureCrop,
                  color: AppColors.teal,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CropHealthSummaryCard extends StatelessWidget {
  final AsyncValue<List<FlightCapture>> captures;
  final AsyncValue<int> detectionsToday;
  final VoidCallback onViewImages;
  final ValueChanged<String> onAskAi;
  final VoidCallback onUpload;

  const _CropHealthSummaryCard({
    required this.captures,
    required this.detectionsToday,
    required this.onViewImages,
    required this.onAskAi,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return captures.when(
      data: (items) {
        final recentWithImage = items.where((c) => c.imageUrl != null).toList();
        if (recentWithImage.isEmpty) {
          return EmptyStateCard(
            icon: Icons.add_photo_alternate_rounded,
            title: 'No crop health analysis yet',
            message:
                'Upload or capture field images to run AI crop disease check.',
            actionLabel: 'Upload Crop Image',
            onAction: onUpload,
            illustrationPath: AppAssets.emptyCropImages,
          );
        }

        final latest = recentWithImage.first;
        final count =
            detectionsToday.maybeWhen(data: (v) => v, orElse: () => 0);

        return AgriGlassCard(
          radius: 28,
          borderColor: AppColors.green.withAlpha(80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crop Health Summary',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image thumbnail
                  if (latest.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        latest.imageUrl!,
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 130,
                          height: 130,
                          color: AppColors.surface2,
                          child: const Icon(Icons.broken_image_rounded,
                              color: AppColors.textFaint),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.image_rounded,
                          color: AppColors.textFaint),
                    ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Risk Level:',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.textDim,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SeverityBadge(
                                severity: count > 0 ? 'Risk Found' : 'Healthy'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          count > 0
                              ? 'We found $count potential crop disease/pest issue(s) in your field. Review the findings and consult with the AI advisor.'
                              : 'No crop disease or pest anomalies have been flagged in your recent images. Your crop appears healthy.',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.text,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onViewImages,
                    icon: const Icon(Icons.photo_library_rounded, size: 16),
                    label: const Text('View Crop Images'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => onAskAi(count > 0
                        ? 'Explain crop health risks in my field and what to do.'
                        : 'What are the best crop maintenance tips for rice paddy season?'),
                    icon: const Icon(Icons.eco_rounded, size: 16),
                    label: const Text('Ask AI Advisor'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FarmSnapshotGrid extends StatelessWidget {
  final AsyncValue<List<CampaignView>> campaigns;
  final AsyncValue<List<FlightSummary>> flights;
  final AsyncValue<FlightSummary?> latestFlight;
  final AsyncValue<List<FlightCapture>> captures;
  final AsyncValue<int> pendingCount;
  final AsyncValue<int> analyzedToday;
  final AsyncValue<int> detectionsToday;
  final AsyncValue<List<dynamic>> pathPoints;
  final DashboardWeatherState weatherState;

  const _FarmSnapshotGrid({
    required this.campaigns,
    required this.flights,
    required this.latestFlight,
    required this.captures,
    required this.pendingCount,
    required this.analyzedToday,
    required this.detectionsToday,
    required this.pathPoints,
    required this.weatherState,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: columns == 4 ? 1.35 : 1.5,
          children: [
            _SnapshotTile(
              title: 'Weather Today',
              value: '28°C · Rainy',
              helper: 'Jhapa, Terai',
              icon: Icons.wb_cloudy_rounded,
              color: AppColors.teal,
            ),
            _SnapshotTile(
              title: 'Crop Health',
              value: detectionsToday.maybeWhen(
                data: (count) => count > 0 ? 'Risk Found' : 'Healthy',
                orElse: () => 'Healthy',
              ),
              helper: detectionsToday.maybeWhen(
                data: (count) =>
                    count > 0 ? '$count issue(s) detected' : 'Field is clear',
                orElse: () => 'No risks found',
              ),
              icon: Icons.health_and_safety_rounded,
              color: AppColors.green,
            ),
            _SnapshotTile(
              title: 'Latest Flight',
              value: latestFlight.maybeWhen(
                data: (flight) => flight == null
                    ? 'None yet'
                    : 'FLT_${flight.flightId.toString().padLeft(4, '0')}',
                orElse: () => 'FLT_0049',
              ),
              helper: latestFlight.maybeWhen(
                data: (flight) => flight == null
                    ? 'No flight data'
                    : '${flight.imageCount} images captured',
                orElse: () => '13 images captured',
              ),
              icon: Icons.flight_takeoff_rounded,
              color: AppColors.teal,
            ),
            _SnapshotTile(
              title: 'Pending Actions',
              value: pendingCount.maybeWhen(
                data: (pending) =>
                    pending > 0 ? '$pending actions' : '0 actions',
                orElse: () => '4 actions',
              ),
              helper: 'Review images, generate report',
              icon: Icons.task_alt_rounded,
              color: AppColors.warn,
            ),
          ],
        );
      },
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;

  const _SnapshotTile({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: value.length > 8 ? 18 : 24,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textFaint,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignsFlightsSection extends ConsumerStatefulWidget {
  final AsyncValue<List<CampaignView>> campaigns;
  final AsyncValue<List<FlightSummary>> flights;
  final Set<int> geotaggedFlightIds;
  final VoidCallback onOpenCampaigns;
  final VoidCallback onAddImages;
  final ValueChanged<String> onAskAi;
  final VoidCallback onViewMap;
  final VoidCallback onCreateReport;

  const _CampaignsFlightsSection({
    required this.campaigns,
    required this.flights,
    required this.geotaggedFlightIds,
    required this.onOpenCampaigns,
    required this.onAddImages,
    required this.onAskAi,
    required this.onViewMap,
    required this.onCreateReport,
  });

  @override
  ConsumerState<_CampaignsFlightsSection> createState() =>
      _CampaignsFlightsSectionState();
}

class _CampaignsFlightsSectionState
    extends ConsumerState<_CampaignsFlightsSection> {
  bool _showCampaigns = true;

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Crop Campaigns & Drone Flights',
            actionLabel: 'Open Campaigns',
            onAction: widget.onOpenCampaigns,
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Campaigns'),
                icon: Icon(Icons.workspaces_rounded),
              ),
              ButtonSegment(
                value: false,
                label: Text('Drone Flights'),
                icon: Icon(Icons.flight_takeoff_rounded),
              ),
            ],
            selected: {_showCampaigns},
            onSelectionChanged: (next) {
              setState(() => _showCampaigns = next.first);
            },
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _showCampaigns
                ? widget.campaigns.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return EmptyStateCard(
                          icon: Icons.workspaces_outline,
                          title: 'No crop campaigns yet',
                          message:
                              'No crop campaigns yet. Create a manual campaign or sync a drone flight.',
                          actionLabel: 'Ask AI how campaigns work',
                          onAction: () => widget
                              .onAskAi('How should I organize crop campaigns?'),
                          illustrationPath: AppAssets.emptyCropImages,
                        );
                      }
                      return _PreviewWrap(
                        children: items
                            .take(3)
                            .map(
                              (campaign) => _CampaignPreviewCard(
                                campaign: campaign,
                                onOpen: widget.onOpenCampaigns,
                                onAskAi: () {
                                  ref
                                      .read(globalAiAdvisorProvider.notifier)
                                      .setCampaignContext(
                                        campaign: campaign.toAdvisorCampaign(),
                                        flight: campaign.toAdvisorFlight(),
                                        pageOverride: 'Campaign Detail',
                                      );
                                  widget.onAskAi(
                                      'Analyze this campaign and tell me what action to take next.');
                                },
                                onAddImages: widget.onAddImages,
                                onViewMap: widget.onViewMap,
                                onCreateReport: campaign.canGenerateReport
                                    ? widget.onCreateReport
                                    : null,
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const _LoadingPanel(
                      message: 'Loading real crop campaigns...',
                    ),
                    error: (_, __) => const _UnavailablePanel(
                      title: 'Campaigns need connection',
                      message:
                          'Campaign data is not available yet. Try again when cloud sync is ready.',
                    ),
                  )
                : widget.flights.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return EmptyStateCard(
                          icon: Icons.flight_takeoff_rounded,
                          title: 'No drone flights yet',
                          message:
                              'No drone flight data yet. Start with a flight checklist or upload crop images.',
                          actionLabel: 'Plan Drone Flight',
                          onAction: () =>
                              widget.onAskAi('Help me plan a drone flight'),
                          illustrationPath: AppAssets.emptyDroneFlights,
                        );
                      }
                      return _PreviewWrap(
                        children: items
                            .take(3)
                            .map(
                              (flight) => _FlightPreviewCard(
                                flight: flight,
                                gpsAvailable: widget.geotaggedFlightIds
                                    .contains(flight.flightId),
                                onOpenCampaigns: widget.onOpenCampaigns,
                                onAskAi: () {
                                  ref
                                      .read(globalAiAdvisorProvider.notifier)
                                      .setCampaignContext(
                                    campaign: const {},
                                    flight: {
                                      'flight_id': flight.flightId,
                                      'image_count': flight.imageCount,
                                      'analyzed_count': flight.analyzedCount,
                                    },
                                    pageOverride: 'Drone Activity',
                                  );
                                  widget.onAskAi(
                                      'Analyze this flight and tell me what action to take next.');
                                },
                                onViewMap: widget.onViewMap,
                                onCreateReport: flight.analyzedCount > 0
                                    ? widget.onCreateReport
                                    : null,
                              ),
                            )
                            .toList(),
                      );
                    },
                    loading: () => const _LoadingPanel(
                      message: 'Loading real drone flights...',
                    ),
                    error: (_, __) => const _UnavailablePanel(
                      title: 'Drone flights need connection',
                      message:
                          'Flight data is not available yet. Try again when cloud sync is ready.',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreviewWrap extends StatelessWidget {
  final List<Widget> children;

  const _PreviewWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 980
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth >= 640
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _CampaignPreviewCard extends StatelessWidget {
  final CampaignView campaign;
  final VoidCallback onOpen;
  final VoidCallback onAskAi;
  final VoidCallback onAddImages;
  final VoidCallback onViewMap;
  final VoidCallback? onCreateReport;

  const _CampaignPreviewCard({
    required this.campaign,
    required this.onOpen,
    required this.onAskAi,
    required this.onAddImages,
    required this.onViewMap,
    required this.onCreateReport,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.workspaces_rounded,
            title: campaign.name,
            meta: campaign.sourceLabel,
          ),
          const SizedBox(height: 12),
          _FactRows(
            rows: [
              ('Crop type', campaign.cropType ?? 'Not available yet'),
              ('Field', campaign.fieldName ?? 'Not linked yet'),
              ('Images', '${campaign.imageCount}'),
              ('Analyzed', '${campaign.analyzedCount}'),
              ('Disease findings', '${campaign.diseaseCount}'),
              (
                'Report',
                campaign.reportAvailable ? 'Ready' : 'Not generated yet',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallAction(label: 'Open Campaign', onPressed: onOpen),
              _SmallAction(label: 'Add Images', onPressed: onAddImages),
              _SmallAction(label: 'Ask AI', onPressed: onAskAi),
              _SmallAction(label: 'View Map', onPressed: onViewMap),
              _SmallAction(
                label: 'Generate Report',
                onPressed: onCreateReport,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlightPreviewCard extends StatelessWidget {
  final FlightSummary flight;
  final bool gpsAvailable;
  final VoidCallback onOpenCampaigns;
  final VoidCallback onAskAi;
  final VoidCallback onViewMap;
  final VoidCallback? onCreateReport;

  const _FlightPreviewCard({
    required this.flight,
    required this.gpsAvailable,
    required this.onOpenCampaigns,
    required this.onAskAi,
    required this.onViewMap,
    required this.onCreateReport,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.flight_takeoff_rounded,
            title: 'FLT_${flight.flightId.toString().padLeft(4, '0')}',
            meta: _flightStatus(flight),
          ),
          const SizedBox(height: 12),
          _FactRows(
            rows: [
              ('Captured images', '${flight.imageCount}'),
              ('GPS status', gpsAvailable ? 'Available' : 'Not available yet'),
              ('Analysis', _analysisStatus(flight)),
              ('Linked campaign', 'Flight campaign'),
              ('Report', 'Not generated yet'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallAction(label: 'Open Campaign', onPressed: onOpenCampaigns),
              _SmallAction(label: 'Ask AI', onPressed: onAskAi),
              _SmallAction(label: 'View Map', onPressed: onViewMap),
              _SmallAction(
                label: 'Generate Report',
                onPressed: onCreateReport,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _analysisStatus(FlightSummary flight) {
    if (flight.analyzedCount == 0) return 'Analysis pending';
    if (flight.fullyProcessed) return 'Analysis complete';
    return '${flight.analyzedCount} analyzed';
  }

  String _flightStatus(FlightSummary flight) {
    if (flight.imageCount == 0) return 'New Flight';
    if (flight.analyzedCount == 0) return 'Images Synced';
    if (flight.fullyProcessed) return 'Analysis Complete';
    return 'Needs Review';
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 18,
      elevated: false,
      borderColor: AppColors.teal.withAlpha(80),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              demoPreviewLabel,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _SoftPanel extends StatelessWidget {
  final Widget child;
  const _SoftPanel({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(216),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.green.withAlpha(45)),
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String meta;

  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.green.withAlpha(22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.green, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                meta,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FactRows extends StatelessWidget {
  final List<(String, String)> rows;

  const _FactRows({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textFaint,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    row.$2,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SmallAction({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Text(label),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final String message;

  const _LoadingPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailablePanel extends StatelessWidget {
  final String title;
  final String message;

  const _UnavailablePanel({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateCard(
      icon: Icons.cloud_off_rounded,
      title: title,
      message: message,
    );
  }
}
