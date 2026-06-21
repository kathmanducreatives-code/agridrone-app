import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_assistant.dart';
import '../models/campaign_view.dart';
import '../models/crop_report.dart';
import '../models/detection.dart';
import 'flight_providers.dart';

/// All stored crop reports, newest first. Returns an empty list (not an error)
/// if the reports table is not set up yet, so the UI stays graceful.
final reportsProvider = FutureProvider<List<CropReport>>((ref) async {
  try {
    final rows = await ref.watch(supabaseServiceProvider).getReports();
    return rows.map(CropReport.fromRow).toList();
  } catch (_) {
    return const [];
  }
});

String _severityFromConfidence(double c) {
  if (c >= 0.75) return 'high';
  if (c >= 0.5) return 'moderate';
  return 'low';
}

/// Generates a real crop report for a campaign via the backend AI Advisor
/// (`/ai/report`, server-side Claude) using only real diagnosis data, then
/// persists it to the reports table.
///
/// If the reports table does not exist yet, the generated report is still
/// returned for in-session viewing (with id `unsaved`).
Future<CropReport> generateCampaignReport(
  WidgetRef ref, {
  required CampaignView campaign,
  required List<Detection> detections,
}) async {
  Detection? top;
  if (detections.isNotEmpty) {
    top = detections.reduce((a, b) => a.confidence >= b.confidence ? a : b);
  }

  final context = top != null
      ? AiDetectionContext(
          captureId: top.flightCaptureId.toString(),
          flightId: top.flightId.toString(),
          diseaseName: top.label,
          confidence: top.confidence,
          severity: _severityFromConfidence(top.confidence),
          cropType: campaign.cropType ?? 'rice',
        )
      : AiDetectionContext(
          diseaseName: 'No disease detected',
          confidence: 0.0,
          severity: 'none',
          cropType: campaign.cropType ?? 'rice',
        );

  final aiReport = await ref.read(aiAssistantServiceProvider).report(context);

  // Enrich the stored JSON with real campaign metadata (never provider/model).
  final reportJson = <String, dynamic>{
    ...aiReport.reportJson,
    'campaign_name': campaign.name,
    'source': campaign.source,
    'image_count': campaign.imageCount,
    'analyzed_count': campaign.analyzedCount,
    'disease_count': campaign.diseaseCount,
  };

  final reportType = campaign.isDroneFlight ? 'flight' : 'campaign';

  try {
    final row = await ref.read(supabaseServiceProvider).saveReport(
          reportType: reportType,
          title: aiReport.title,
          reportMarkdown: aiReport.reportMarkdown,
          reportJson: reportJson,
          campaignId: campaign.manualId,
          flightId: campaign.flightId?.toString(),
        );
    ref.invalidate(reportsProvider);
    return CropReport.fromRow(row);
  } catch (_) {
    // Reports table not set up yet — return an in-session (unsaved) report.
    return CropReport(
      id: 'unsaved',
      reportType: reportType,
      title: aiReport.title,
      reportMarkdown: aiReport.reportMarkdown,
      reportJson: reportJson,
      campaignId: campaign.manualId,
      flightId: campaign.flightId?.toString(),
      createdAt: DateTime.now(),
    );
  }
}
