import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
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
import 'test_ai_screen.dart';

enum DashboardWeatherState { notConnected, connected }

final dashboardWeatherProvider = Provider<DashboardWeatherState>((ref) {
  return DashboardWeatherState.notConnected;
});

final dashboardImageAnalysisHealthProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  try {
    await ref.watch(huggingFaceServiceProvider).health();
    return true;
  } catch (_) {
    return false;
  }
});

final dashboardAiAdvisorHealthProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  try {
    final health = await ref.watch(aiAssistantServiceProvider).health();
    return health['ai_endpoints_available'] == true ||
        health['anthropic_configured'] == true;
  } catch (_) {
    return false;
  }
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
    final imageAnalysisReady = ref.watch(dashboardImageAnalysisHealthProvider);
    final aiAdvisorReady = ref.watch(dashboardAiAdvisorHealthProvider);
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
                imageAnalysisReady: imageAnalysisReady,
                aiAdvisorReady: aiAdvisorReady,
                weatherState: weatherState,
                onCheckCrop: () => _openCheckCrop(context),
                onAskAi: () => _openAdvisor(ref),
              ),
              if (demoMode) ...[
                const SizedBox(height: 16),
                const _DemoNotice(),
              ],
              const SizedBox(height: 18),
              _DashboardAiCard(
                onSubmit: (message) => _sendDashboardPrompt(ref, message),
              ),
              const SizedBox(height: 18),
              _FarmSnapshotGrid(
                campaigns: campaigns,
                flights: flights,
                latestFlight: latestFlight,
                captures: captures,
                pendingCount: pendingCount,
                analyzedToday: analyzedToday,
                detectionsToday: detectionsToday,
                pathPoints: pathPoints,
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 18),
              _RecentImagesSection(
                captures: captures,
                onUpload: () => _openCheckCrop(context),
                onOpenImages: () =>
                    ref.read(currentTabProvider.notifier).set(3),
                onAskAi: (prompt) => _sendDashboardPrompt(ref, prompt),
              ),
              const SizedBox(height: 18),
              _FieldMapPreview(
                pathPoints: pathPoints,
                onOpenMap: () => ref.read(currentTabProvider.notifier).set(5),
                onAskAi: () => _sendDashboardPrompt(
                  ref,
                  'How do I map my field and connect crop images to locations?',
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  final reports = _ReportsSummaryCard(
                    hasAnalyzedImages: analyzedToday.maybeWhen(
                      data: (value) => value > 0,
                      orElse: () => false,
                    ),
                    onOpenReports: () =>
                        ref.read(currentTabProvider.notifier).set(6),
                  );
                  final actions = _ActionSummaryCard(
                    pendingCount: pendingCount,
                    detectionsToday: detectionsToday,
                    onOpenActions: () =>
                        ref.read(currentTabProvider.notifier).set(7),
                    onAskAi: () =>
                        _sendDashboardPrompt(ref, 'What should I do today?'),
                  );
                  if (!wide) {
                    return Column(
                      children: [
                        reports,
                        const SizedBox(height: 16),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: reports),
                      const SizedBox(width: 18),
                      Expanded(child: actions),
                    ],
                  );
                },
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
    ref.read(currentTabProvider.notifier).set(1);
    ref.read(globalAiAdvisorProvider.notifier).open();
  }

  void _sendDashboardPrompt(WidgetRef ref, String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    ref.read(currentTabProvider.notifier).set(1);
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
  final AsyncValue<bool> imageAnalysisReady;
  final AsyncValue<bool> aiAdvisorReady;
  final DashboardWeatherState weatherState;
  final VoidCallback onCheckCrop;
  final VoidCallback onAskAi;

  const _GreetingHero({
    required this.profile,
    required this.latestFlight,
    required this.imageAnalysisReady,
    required this.aiAdvisorReady,
    required this.weatherState,
    required this.onCheckCrop,
    required this.onAskAi,
  });

  @override
  Widget build(BuildContext context) {
    final greetingName = profile.operatorName.trim().isNotEmpty
        ? profile.operatorName.trim()
        : profile.farmName.trim().isNotEmpty
            ? profile.farmName.trim()
            : 'Farmer';
    final cloudReady = latestFlight.hasError ? false : latestFlight.hasValue;
    return AgriGlassCard(
      radius: 34,
      padding: const EdgeInsets.all(28),
      borderColor: AppColors.green.withAlpha(70),
      child: Stack(
        children: [
          const Positioned.fill(child: _TerraceHillsDecoration()),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_timeGreeting()}, $greetingName',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: wide ? 36 : 28,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Here is what your farm needs today.',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.greenDeep,
                      fontSize: wide ? 22 : 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ask AI, review crop campaigns, and plan today’s field actions.',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textDim,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  if (profile.farmName.trim().isEmpty &&
                      profile.operatorName.trim().isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Complete your farm profile to personalize AI advice.',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.warn,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              );
              final actions = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: onAskAi,
                    icon: const Icon(Icons.eco_rounded),
                    label: const Text('Ask AI Advisor'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCheckCrop,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Check Crop Image'),
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
                            const SizedBox(width: 20),
                            actions,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            copy,
                            const SizedBox(height: 18),
                            actions,
                          ],
                        ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SystemStatusChip(
                        label: 'Cloud Sync',
                        status: cloudReady ? 'Ready' : 'Needs Connection',
                        ok: cloudReady,
                        icon: Icons.cloud_done_rounded,
                      ),
                      SystemStatusChip(
                        label: 'Image Analysis',
                        status: imageAnalysisReady.maybeWhen(
                          data: (ready) => ready ? 'Ready' : 'Needs Connection',
                          orElse: () => 'Checking',
                        ),
                        ok: imageAnalysisReady.maybeWhen(
                          data: (ready) => ready,
                          orElse: () => false,
                        ),
                        icon: Icons.image_search_rounded,
                      ),
                      SystemStatusChip(
                        label: 'AI Advisor',
                        status: aiAdvisorReady.maybeWhen(
                          data: (ready) => ready ? 'Ready' : 'Needs Connection',
                          orElse: () => 'Checking',
                        ),
                        ok: aiAdvisorReady.maybeWhen(
                          data: (ready) => ready,
                          orElse: () => false,
                        ),
                        icon: Icons.auto_awesome_rounded,
                      ),
                      SystemStatusChip(
                        label: 'Weather',
                        status: weatherState == DashboardWeatherState.connected
                            ? 'Connected'
                            : 'Not Connected',
                        ok: weatherState == DashboardWeatherState.connected,
                        icon: Icons.wb_cloudy_rounded,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _TerraceHillsDecoration extends StatelessWidget {
  const _TerraceHillsDecoration();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _TerraceHillsPainter(),
      ),
    );
  }
}

class _TerraceHillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.green.withAlpha(40);
    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.warn.withAlpha(32);

    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.28 + i * 0.085);
      final path = Path()..moveTo(size.width * 0.48, y);
      for (var x = size.width * 0.48; x <= size.width; x += 24) {
        final progress = (x - size.width * 0.48) / (size.width * 0.52);
        path.lineTo(
          x,
          y + math.sin(progress * math.pi * 2 + i) * 8 + i * 3,
        );
      }
      canvas.drawPath(path, i.isEven ? hillPaint : accentPaint);
    }

    final sunPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.green.withAlpha(22);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.18),
      46,
      sunPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardAiCard extends ConsumerStatefulWidget {
  final ValueChanged<String> onSubmit;

  const _DashboardAiCard({required this.onSubmit});

  @override
  ConsumerState<_DashboardAiCard> createState() => _DashboardAiCardState();
}

class _DashboardAiCardState extends ConsumerState<_DashboardAiCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'What should I do today?',
      'Which campaign needs attention?',
      'Summarize my latest flight',
      'Create a crop report',
      'Help me plan a drone flight',
      'What data is missing?',
    ];

    return AgriGlassCard(
      radius: 30,
      borderColor: AppColors.green.withAlpha(90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.green.withAlpha(28),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green.withAlpha(80)),
                ),
                child: const Icon(Icons.eco_rounded, color: AppColors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask AgriDrone AI Advisor',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Get help with crop health, campaigns, drone flights, field maps, water needs, and reports.',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.textDim,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(220),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.green.withAlpha(58)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submit,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Ask what your farm needs today...',
                      hintStyle: GoogleFonts.spaceGrotesk(
                        color: AppColors.textFaint,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _submit(_controller.text),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Ask'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in prompts)
                ActionChip(
                  label: Text(prompt),
                  onPressed: () => _submit(prompt),
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSubmit(text);
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

  const _FarmSnapshotGrid({
    required this.campaigns,
    required this.flights,
    required this.latestFlight,
    required this.captures,
    required this.pendingCount,
    required this.analyzedToday,
    required this.detectionsToday,
    required this.pathPoints,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 6
            : constraints.maxWidth >= 820
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns >= 3 ? 1.1 : 1.24,
          children: [
            _SnapshotTile(
              title: 'Active Campaigns',
              value: campaigns.maybeWhen(
                data: (items) => '${items.length}',
                orElse: () => 'Not available yet',
              ),
              helper: 'Real flight campaigns',
              icon: Icons.workspaces_rounded,
              color: AppColors.green,
            ),
            _SnapshotTile(
              title: 'Latest Drone Flight',
              value: latestFlight.maybeWhen(
                data: (flight) => flight == null
                    ? 'Not available yet'
                    : 'FLT_${flight.flightId.toString().padLeft(4, '0')}',
                orElse: () => 'Not available yet',
              ),
              helper: flights.maybeWhen(
                data: (items) => items.isEmpty
                    ? 'No drone flight data yet'
                    : '${items.length} total flight(s)',
                orElse: () => 'Waiting for flight data',
              ),
              icon: Icons.flight_takeoff_rounded,
              color: AppColors.teal,
            ),
            _SnapshotTile(
              title: 'Crop Images',
              value: captures.maybeWhen(
                data: (items) => '${items.length}',
                orElse: () => 'Not available yet',
              ),
              helper: analyzedToday.maybeWhen(
                data: (count) => '$count checked in last 24h',
                orElse: () => 'Analysis count unavailable',
              ),
              icon: Icons.photo_library_rounded,
              color: AppColors.info,
            ),
            const _SnapshotTile(
              title: 'Reports Ready',
              value: 'Not available yet',
              helper: 'Reports appear after generation',
              icon: Icons.description_rounded,
              color: AppColors.greenDeep,
            ),
            _SnapshotTile(
              title: 'Actions Needed',
              value: pendingCount.maybeWhen(
                data: (pending) => detectionsToday.maybeWhen(
                  data: (disease) => '${pending + disease}',
                  orElse: () => '$pending',
                ),
                orElse: () => 'Not available yet',
              ),
              helper: 'From review and crop findings',
              icon: Icons.task_alt_rounded,
              color: AppColors.warn,
            ),
            _SnapshotTile(
              title: 'Fields Mapped',
              value: 'Not available yet',
              helper: pathPoints.maybeWhen(
                data: (points) => points.isEmpty
                    ? 'No GPS-linked images yet'
                    : '${points.length} GPS-linked image(s)',
                orElse: () => 'Map data unavailable',
              ),
              icon: Icons.map_rounded,
              color: AppColors.green,
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

class _CampaignsFlightsSection extends StatefulWidget {
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
  State<_CampaignsFlightsSection> createState() =>
      _CampaignsFlightsSectionState();
}

class _CampaignsFlightsSectionState extends State<_CampaignsFlightsSection> {
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
                        );
                      }
                      return _PreviewWrap(
                        children: items
                            .take(3)
                            .map(
                              (campaign) => _CampaignPreviewCard(
                                campaign: campaign,
                                onOpen: widget.onOpenCampaigns,
                                onAskAi: () => widget
                                    .onAskAi('Which campaign needs attention?'),
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
                                onAskAi: () => widget
                                    .onAskAi('Summarize my latest flight'),
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

class _RecentImagesSection extends StatelessWidget {
  final AsyncValue<List<FlightCapture>> captures;
  final VoidCallback onUpload;
  final VoidCallback onOpenImages;
  final ValueChanged<String> onAskAi;

  const _RecentImagesSection({
    required this.captures,
    required this.onUpload,
    required this.onOpenImages,
    required this.onAskAi,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Recent Crop Images',
            actionLabel: 'Open Crop Images',
            onAction: onOpenImages,
          ),
          const SizedBox(height: 16),
          captures.when(
            data: (items) {
              final recent =
                  items.where((capture) => capture.imageUrl != null).take(4);
              if (items.isEmpty || recent.isEmpty) {
                return EmptyStateCard(
                  icon: Icons.add_photo_alternate_rounded,
                  title: 'No crop images yet',
                  message:
                      'No crop images yet. Upload images or sync a drone flight to begin.',
                  actionLabel: 'Upload Crop Image',
                  onAction: onUpload,
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 960
                      ? (constraints.maxWidth - 36) / 4
                      : constraints.maxWidth >= 620
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final capture in recent)
                        SizedBox(
                          width: width,
                          child: _RecentImageCard(
                            capture: capture,
                            onOpenImages: onOpenImages,
                            onAskAi: () => onAskAi(
                              'What should I check in image ${capture.imageIndex}?',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
            loading: () =>
                const _LoadingPanel(message: 'Loading real crop images...'),
            error: (_, __) => const _UnavailablePanel(
              title: 'Crop images need connection',
              message:
                  'Crop images are not available yet. Try again when cloud sync is ready.',
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentImageCard extends StatelessWidget {
  final FlightCapture capture;
  final VoidCallback onOpenImages;
  final VoidCallback onAskAi;

  const _RecentImageCard({
    required this.capture,
    required this.onOpenImages,
    required this.onAskAi,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CachedNetworkImage(
                imageUrl: capture.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.surface2,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.green),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surface2,
                  child: const Icon(Icons.image_not_supported_rounded,
                      color: AppColors.textFaint),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Flight FLT_${capture.flightId.toString().padLeft(4, '0')}',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Image #${capture.imageIndex} · ${capture.aiProcessed ? 'Checked' : 'Needs analysis'}',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniBadge(capture.aiProcessed ? 'Checked' : 'Analyze'),
              const _MiniBadge('GPS: Not available yet'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallAction(
                label: capture.aiProcessed ? 'Open Diagnosis' : 'Analyze',
                onPressed: onOpenImages,
              ),
              _SmallAction(label: 'Ask AI', onPressed: onAskAi),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldMapPreview extends StatelessWidget {
  final AsyncValue<List<dynamic>> pathPoints;
  final VoidCallback onOpenMap;
  final VoidCallback onAskAi;

  const _FieldMapPreview({
    required this.pathPoints,
    required this.onOpenMap,
    required this.onAskAi,
  });

  @override
  Widget build(BuildContext context) {
    final pointCount = pathPoints.maybeWhen(
      data: (points) => points.length,
      orElse: () => 0,
    );
    return AgriGlassCard(
      radius: 30,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 880;
          final visual = _MapMiniCanvas(pointCount: pointCount);
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: 'Field Map',
                actionLabel: 'Open Field Map',
                onAction: onOpenMap,
              ),
              const SizedBox(height: 14),
              _FactRows(
                rows: [
                  ('Saved fields', 'Not available yet'),
                  (
                    'GPS-linked images',
                    pointCount == 0 ? 'Not available yet' : '$pointCount',
                  ),
                  ('Local weather', 'Local weather is not connected yet.'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                pointCount == 0
                    ? 'Map your field using your current location or by moving the map manually. Drone GPS data is not connected yet. GPS-linked crop images will appear after a flight.'
                    : 'GPS-linked crop images are available. Open the map to inspect field locations.',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Open Field Map'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Use My Location'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.crop_square_rounded),
                    label: const Text('Map Field'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAskAi,
                    icon: const Icon(Icons.eco_rounded),
                    label: const Text('Ask AI'),
                  ),
                ],
              ),
            ],
          );
          if (!wide) {
            return Column(
              children: [
                copy,
                const SizedBox(height: 16),
                visual,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 5, child: copy),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: visual),
            ],
          );
        },
      ),
    );
  }
}

class _MapMiniCanvas extends StatelessWidget {
  final int pointCount;

  const _MapMiniCanvas({required this.pointCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.green.withAlpha(16),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.green.withAlpha(58)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _TerraceHillsDecoration()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pointCount == 0
                      ? Icons.add_location_alt_outlined
                      : Icons.location_on_rounded,
                  color: AppColors.green,
                  size: 38,
                ),
                const SizedBox(height: 10),
                Text(
                  pointCount == 0
                      ? 'No field locations yet'
                      : '$pointCount GPS-linked image(s)',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    pointCount == 0
                        ? 'GPS-linked crop images will appear here after a flight.'
                        : 'Open the map to view real capture locations.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textDim,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsSummaryCard extends StatelessWidget {
  final bool hasAnalyzedImages;
  final VoidCallback onOpenReports;

  const _ReportsSummaryCard({
    required this.hasAnalyzedImages,
    required this.onOpenReports,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.description_rounded,
            title: 'Reports',
            meta: 'Crop Report',
          ),
          const SizedBox(height: 14),
          Text(
            'No crop report yet. Analyze a crop image first.',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onOpenReports,
            icon: const Icon(Icons.description_rounded),
            label: Text(hasAnalyzedImages ? 'Create Report' : 'Open Reports'),
          ),
        ],
      ),
    );
  }
}

class _ActionSummaryCard extends StatelessWidget {
  final AsyncValue<int> pendingCount;
  final AsyncValue<int> detectionsToday;
  final VoidCallback onOpenActions;
  final VoidCallback onAskAi;

  const _ActionSummaryCard({
    required this.pendingCount,
    required this.detectionsToday,
    required this.onOpenActions,
    required this.onAskAi,
  });

  @override
  Widget build(BuildContext context) {
    final pending =
        pendingCount.maybeWhen(data: (value) => value, orElse: () => 0);
    final detections =
        detectionsToday.maybeWhen(data: (value) => value, orElse: () => 0);
    final hasActions = pending > 0 || detections > 0;

    return AgriGlassCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.task_alt_rounded,
            title: 'Action Plan',
            meta: hasActions ? 'Needs attention' : 'No open field actions',
          ),
          const SizedBox(height: 14),
          if (hasActions) ...[
            if (pending > 0)
              _ActionLine('Review $pending crop image(s)',
                  'These images are waiting for farmer review.'),
            if (detections > 0)
              _ActionLine('Review $detections crop finding(s)',
                  'Ask the AI Advisor before taking treatment decisions.'),
          ] else
            Text(
              'No field actions yet. Actions will appear after crop analysis or campaign review.',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: onOpenActions,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Open Action Plan'),
              ),
              OutlinedButton.icon(
                onPressed: onAskAi,
                icon: const Icon(Icons.eco_rounded),
                label: const Text('Ask AI'),
              ),
            ],
          ),
        ],
      ),
    );
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
  final EdgeInsetsGeometry padding;

  const _SoftPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
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

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.green.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.green.withAlpha(58)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.text,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionLine extends StatelessWidget {
  final String title;
  final String body;

  const _ActionLine(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.green, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
