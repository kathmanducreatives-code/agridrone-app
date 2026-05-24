import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_dot.dart';
import '../models/detection.dart';
import '../providers/dashboard_providers.dart';
import '../providers/flight_providers.dart';
import '../providers/realtime_providers.dart';
import '../services/realtime_service.dart';

/// Curation dashboard showing real-time statistics, weekly progress, and active mission profiles.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatFlightTime(int? ms) {
    if (ms == null) return '—';
    if (ms > 100000000000) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } else {
      final secs = ms ~/ 1000;
      final mins = secs ~/ 60;
      final remainingSecs = secs % 60;
      return '${mins}m ${remainingSecs}s';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connStateAsync = ref.watch(realtimeConnectionProvider);
    final latestFlightAsync = ref.watch(latestFlightSummaryProvider);
    final pendingCountAsync = ref.watch(pendingReviewCountProvider);
    final analyzedCountAsync = ref.watch(analyzedTodayCountProvider);
    final todayDetectionsAsync = ref.watch(todayDetectionsCountProvider);
    final alertLevelAsync = ref.watch(diseaseAlertLevelProvider);
    final recentDetectionsAsync = ref.watch(recentDetectionsProvider);
    final chartDataAsync = ref.watch(dailyChartDataProvider);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AGRIDRONE GUARDIAN',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
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
                        style: GoogleFonts.jetBrainsMono(
                          color: connectionColor,
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // 2. Latest Flight Hero Card
              latestFlightAsync.when(
                data: (summary) {
                  if (summary == null) {
                    return const GlassCard(
                      child: Center(
                        child: Text(
                          'No flights found in database',
                          style: TextStyle(color: AppColors.textDim, fontFamily: 'Space Grotesk'),
                        ),
                      ),
                    );
                  }

                  final bool fullyProcessed = summary.pendingReview == 0 && summary.fullyProcessed;

                  return GlassCard(
                    bright: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LATEST FLIGHT PROFILE',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppColors.textDim,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  'FLT_${summary.flightId.toString().padLeft(4, '0')}',
                                  style: GoogleFonts.syne(
                                    color: AppColors.green,
                                    fontSize: 28.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                              decoration: BoxDecoration(
                                color: fullyProcessed
                                    ? AppColors.green.withAlpha((255 * 0.1).toInt())
                                    : AppColors.warn.withAlpha((255 * 0.1).toInt()),
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                  color: fullyProcessed ? AppColors.green : AppColors.warn,
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    fullyProcessed ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                                    size: 14.0,
                                    color: fullyProcessed ? AppColors.green : AppColors.warn,
                                  ),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    fullyProcessed ? 'COMPLETED' : 'CURATION QUEUE',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: fullyProcessed ? AppColors.green : AppColors.warn,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20.0),
                        
                        // Detailed Curation Counts
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildHeroStat('TOTAL CAPTURES', summary.imageCount.toString()),
                            _buildHeroStat('PENDING REVIEW', summary.pendingReview.toString(), highlight: summary.pendingReview > 0),
                            _buildHeroStat('ANALYZED', summary.analyzedCount.toString()),
                            _buildHeroStat('REJECTED', summary.rejectedCount.toString()),
                          ],
                        ),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(color: AppColors.line, height: 1.0),
                        ),
                        
                        // Telemetry details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AVG MOISTURE: ${summary.avgMoisturePct != null ? '${summary.avgMoisturePct!.toStringAsFixed(1)}%' : '—'}',
                              style: GoogleFonts.jetBrainsMono(color: AppColors.textDim, fontSize: 11.0),
                            ),
                            Text(
                              'SPAN: ${_formatFlightTime(summary.startedAtMs)} ↔ ${_formatFlightTime(summary.endedAtMs)}',
                              style: GoogleFonts.jetBrainsMono(color: AppColors.textFaint, fontSize: 11.0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const GlassCard(
                  child: SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator(color: AppColors.green)),
                  ),
                ),
                error: (err, stack) => GlassCard(
                  child: Center(
                    child: Text('Failed to load latest flight aggregates: $err', style: const TextStyle(color: AppColors.crit)),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // 3. Four KPI Tiles (2x2 Grid)
              _buildKpiGrid(ref, pendingCountAsync, analyzedCountAsync, todayDetectionsAsync, alertLevelAsync),
              const SizedBox(height: 24.0),

              // 4. Recent Analyses horizontal strip list
              Text(
                'LATEST CROP DETECTION STREAM',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12.0),
              SizedBox(
                height: 96.0,
                child: recentDetectionsAsync.when(
                  data: (detections) {
                    if (detections.isEmpty) {
                      return const Center(
                        child: Text(
                          'No active infections detected',
                          style: TextStyle(color: AppColors.textFaint, fontSize: 12.0),
                        ),
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: detections.length,
                      itemBuilder: (context, index) {
                        return _buildRecentAnalysisCard(detections[index]);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
                  error: (err, stack) => Center(
                    child: Text('Error: $err', style: const TextStyle(color: AppColors.crit, fontSize: 12.0)),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // 5. Weekly Chart Card (Analyzed count)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INFERENCES BY DAY (LAST 7 DAYS)',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.textDim,
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      height: 160.0,
                      child: chartDataAsync.when(
                        data: (chartData) {
                          if (chartData.isEmpty) {
                            return const Center(
                              child: Text(
                                'No analyses processed during this period',
                                style: TextStyle(color: AppColors.textFaint, fontSize: 12.0),
                              ),
                            );
                          }
                          return _buildWeeklyChart(chartData);
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
                        error: (err, stack) => Center(
                          child: Text('Error loading statistics: $err', style: const TextStyle(color: AppColors.crit, fontSize: 12.0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStat(String title, String val, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.textFaint,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          val,
          style: GoogleFonts.syne(
            color: highlight ? AppColors.warn : AppColors.text,
            fontSize: 18.0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(
    WidgetRef ref,
    AsyncValue<int> pendingAsync,
    AsyncValue<int> analyzedAsync,
    AsyncValue<int> todayDetectionsAsync,
    AsyncValue<AlertLevel> alertLevelAsync,
  ) {
    final pendingCount = pendingAsync.value ?? 0;
    final analyzedCount = analyzedAsync.value ?? 0;
    final detectionsCount = todayDetectionsAsync.value ?? 0;
    final alertLevel = alertLevelAsync.value ?? AlertLevel.low;

    Color alertColor = AppColors.green;
    String alertText = 'LOW';
    if (alertLevel == AlertLevel.high) {
      alertColor = AppColors.crit;
      alertText = 'HIGH';
    } else if (alertLevel == AlertLevel.medium) {
      alertColor = AppColors.warn;
      alertText = 'MEDIUM';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.6,
          children: [
            _buildStatTile(
              'PENDING REVIEW',
              pendingCount.toString(),
              Icons.pending_actions_outlined,
              pendingCount > 0 ? AppColors.warn : AppColors.green,
            ),
            _buildStatTile(
              'ANALYZED TODAY',
              analyzedCount.toString(),
              Icons.done_all_outlined,
              AppColors.greenSoft,
            ),
            _buildStatTile(
              "TODAY'S INFECTIONS",
              detectionsCount.toString(),
              Icons.radar_outlined,
              AppColors.greenLime,
            ),
            _buildStatTile(
              'DISEASE THREAT',
              alertText,
              Icons.warning_amber_outlined,
              alertColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textFaint,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, size: 14.0, color: color),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.syne(
              color: color,
              fontSize: 20.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAnalysisCard(Detection item) {
    final imageUrl = item.imageUrl ?? '';
    return Container(
      width: 220.0,
      margin: const EdgeInsets.only(right: 12.0),
      child: GlassCard(
        bright: false,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: SizedBox(
                width: 64.0,
                height: 64.0,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: AppColors.surface2),
                      )
                    : Container(color: AppColors.surface2),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.displayLabel,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Space Grotesk',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'FLT_${item.flightId.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 9.0,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    item.confidencePercent,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(List<Map<String, dynamic>> chartData) {
    List<BarChartGroupData> groups = [];
    for (int i = 0; i < chartData.length; i++) {
      final count = chartData[i]['count'] as int? ?? 0;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: AppColors.green,
              width: 14.0,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4.0)),
            ),
          ],
        ),
      );
    }

    double maxY = 10.0;
    if (chartData.isNotEmpty) {
      final counts = chartData.map((e) => e['count'] as int);
      final maxVal = counts.reduce((a, b) => a > b ? a : b).toDouble();
      if (maxVal > 8.0) {
        maxY = maxVal + 2.0;
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: groups,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= chartData.length) return const SizedBox.shrink();
                final dateStr = chartData[idx]['date'] as String;
                final parts = dateStr.split('-');
                final label = parts.length == 3 ? '${parts[1]}/${parts[2]}' : dateStr;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 9.0,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
