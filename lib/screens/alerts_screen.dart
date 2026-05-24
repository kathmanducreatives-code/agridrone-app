import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../providers/flight_providers.dart';
import '../providers/dashboard_providers.dart';

/// Representation of a derived alert notification.
class DerivedAlert {
  final String id;
  final String title;
  final String body;
  final String severity; // 'CRITICAL', 'WARNING', 'INFO'
  final DateTime timestamp;

  const DerivedAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.timestamp,
  });
}

/// Notifier holding the locally dismissed alert IDs.
class DismissedAlertsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void dismiss(String id) {
    state = {...state, id};
  }

  void restoreAll() {
    state = {};
  }
}

/// Provider containing active dismissed alerts.
final dismissedAlertsProvider = NotifierProvider<DismissedAlertsNotifier, Set<String>>(
  DismissedAlertsNotifier.new,
);

/// Computed Provider evaluating live data feeds and evaluating alerts on-the-fly.
final derivedAlertsProvider = Provider<AsyncValue<List<DerivedAlert>>>((ref) {
  final detectionsAsync = ref.watch(allDetectionsProvider);
  final capturesAsync = ref.watch(allFlightCapturesProvider);
  final flightsAsync = ref.watch(allFlightsProvider);
  final pendingCountAsync = ref.watch(pendingReviewCountProvider);
  final dismissed = ref.watch(dismissedAlertsProvider);

  return detectionsAsync.when(
    data: (detections) {
      return capturesAsync.when(
        data: (captures) {
          return flightsAsync.when(
            data: (flights) {
              final List<DerivedAlert> alerts = [];
              final now = DateTime.now();

              // Rule 1: Curation backlog (pending review count > 20)
              final pendingCount = pendingCountAsync.value ?? 0;
              if (pendingCount > 20) {
                alerts.add(
                  DerivedAlert(
                    id: 'curation_backlog',
                    title: 'Curation queue backlog warning',
                    body: 'You have $pendingCount drone images awaiting review. Head to Lab to filter and trigger analysis.',
                    severity: 'WARNING',
                    timestamp: now,
                  ),
                );
              }

              // Rule 2: High-confidence disease detection in last hour
              final oneHourAgo = now.subtract(const Duration(hours: 1));
              for (final det in detections) {
                if (det.confidence > 0.85 && det.detectedAt.isAfter(oneHourAgo)) {
                  alerts.add(
                    DerivedAlert(
                      id: 'high_conf_${det.id}',
                      title: 'Confirmed ${det.displayLabel} in FLT_${det.flightId.toString().padLeft(4, '0')}',
                      body: 'Infection confirmed with ${(det.confidence * 100).toStringAsFixed(1)}% confidence at index #${det.imageIndex}.',
                      severity: 'CRITICAL',
                      timestamp: det.detectedAt,
                    ),
                  );
                }
              }

              // Rule 3: Stuck analysis (analysis_requested_at set but not processed > 2 mins)
              final twoMinutesAgo = now.subtract(const Duration(minutes: 2));
              for (final cap in captures) {
                if (!cap.aiProcessed &&
                    cap.analysisRequestedAt != null &&
                    cap.analysisRequestedAt!.isBefore(twoMinutesAgo)) {
                  alerts.add(
                    DerivedAlert(
                      id: 'stuck_analysis_${cap.id}',
                      title: 'Analysis stalled in FLT_${cap.flightId}',
                      body: 'Image index #${cap.imageIndex} request has been pending for over 2 minutes. FastAPI worker may be slow.',
                      severity: 'WARNING',
                      timestamp: cap.analysisRequestedAt!,
                    ),
                  );
                }
              }

              // Rule 4: Disease density alert (> 3 detections of same label in one flight)
              final densityMap = <String, int>{}; // Key format: 'flightId_label'
              final densityOldest = <String, DateTime>{};
              for (final det in detections) {
                final key = '${det.flightId}_${det.label}';
                densityMap[key] = (densityMap[key] ?? 0) + 1;
                final currentOldest = densityOldest[key];
                if (currentOldest == null || det.detectedAt.isBefore(currentOldest)) {
                  densityOldest[key] = det.detectedAt;
                }
              }

              densityMap.forEach((key, count) {
                if (count > 3) {
                  final parts = key.split('_');
                  final flightId = parts[0];
                  final label = parts.sublist(1).join('_');
                  final cleanLabel = label.replaceAll('_', ' ');
                  alerts.add(
                    DerivedAlert(
                      id: 'density_$key',
                      title: 'Disease density alert in FLT_${flightId.padLeft(4, '0')}',
                      body: 'Identified $count instances of $cleanLabel during flight $flightId. High risk of disease spreading.',
                      severity: 'CRITICAL',
                      timestamp: densityOldest[key] ?? now,
                    ),
                  );
                }
              });

              // Rule 5: Coverage gap (if no captures uploaded in last 24 hours)
              if (captures.isNotEmpty) {
                final validTimes = captures.map((c) => c.uploadedAt).where((t) => t != null).cast<DateTime>();
                if (validTimes.isNotEmpty) {
                  final latestUpload = validTimes.reduce((a, b) => a.isAfter(b) ? a : b);
                  final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));
                  if (latestUpload.isBefore(twentyFourHoursAgo)) {
                    final hours = now.difference(latestUpload).inHours;
                    alerts.add(
                      DerivedAlert(
                        id: 'coverage_gap',
                        title: 'No recent drone activity',
                        body: 'No captures sync log found in Supabase in the last $hours hours. Verify hardware sync profiles.',
                        severity: 'WARNING',
                        timestamp: latestUpload,
                      ),
                    );
                  }
                }
              }

              // Filter out resolved alerts and sort descending
              final activeAlerts = alerts.where((a) => !dismissed.contains(a.id)).toList();
              activeAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return AsyncValue.data(activeAlerts);
            },
            loading: () => const AsyncValue.loading(),
            error: (err, stack) => AsyncValue.error(err, stack),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Screen displaying critical notifications and crop protection warnings.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(derivedAlertsProvider);
    final dismissedCount = ref.watch(dismissedAlertsProvider).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WARNING LOG DIRECTORY',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontSize: 20.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'DIAGNOSED DIAGNOSTICS & SYSTEM WARNINGS',
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.textDim,
                          fontSize: 10.0,
                        ),
                      ),
                    ],
                  ),
                  if (dismissedCount > 0)
                    TextButton(
                      onPressed: () => ref.read(dismissedAlertsProvider.notifier).restoreAll(),
                      child: Text(
                        'RESTORE ALL',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.green,
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20.0),

              // Alerts list
              Expanded(
                child: alertsAsync.when(
                  data: (alerts) {
                    if (alerts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_outlined, size: 48.0, color: AppColors.green),
                            const SizedBox(height: 16.0),
                            Text(
                              'ALL SYSTEMS CLEAN',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.text,
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'No threat backlog, density errors, or queue delays detected currently.',
                              style: GoogleFonts.spaceGrotesk(color: AppColors.textDim, fontSize: 13.0),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildAlertCard(context, ref, alert),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
                  error: (err, stack) => Center(
                    child: Text('Error loading warnings: $err', style: const TextStyle(color: AppColors.crit)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, WidgetRef ref, DerivedAlert alert) {
    Color severityColor = AppColors.green;
    IconData severityIcon = Icons.check_circle_outline_rounded;
    if (alert.severity == 'CRITICAL') {
      severityColor = AppColors.crit;
      severityIcon = Icons.warning_amber_rounded;
    } else if (alert.severity == 'WARNING') {
      severityColor = AppColors.warn;
      severityIcon = Icons.info_outline;
    }

    return GlassCard(
      bright: alert.severity == 'CRITICAL',
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: severityColor.withAlpha((255 * 0.1).toInt()),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: severityColor.withAlpha((255 * 0.2).toInt()), width: 1.0),
            ),
            child: Icon(severityIcon, color: severityColor, size: 20.0),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: severityColor.withAlpha((255 * 0.1).toInt()),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: severityColor, width: 0.5),
                      ),
                      child: Text(
                        alert.severity,
                        style: GoogleFonts.spaceGrotesk(
                          color: severityColor,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _formatTimeAgo(alert.timestamp),
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.textFaint,
                        fontSize: 10.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  alert.title,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  alert.body,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim,
                    fontSize: 12.0,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12.0),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    onPressed: () => ref.read(dismissedAlertsProvider.notifier).dismiss(alert.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                    ),
                    child: Text(
                      'RESOLVE',
                      style: GoogleFonts.spaceGrotesk(fontSize: 10.0, fontWeight: FontWeight.bold),
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
