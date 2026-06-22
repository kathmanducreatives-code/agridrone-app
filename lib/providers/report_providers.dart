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

/// Builds a polished, campaign-wide Crop Health Report from the campaign's real
/// persisted Image Analysis results + supplemental field context, via the AI
/// Advisor chat (server-side). Used for manual campaigns.
Future<CropReport> _generateCampaignReportFromContext(
  WidgetRef ref,
  CampaignView campaign,
) async {
  final title = 'Crop Campaign Report — ${campaign.name}';
  final instruction =
      'Generate a complete, polished Crop Health Report for this campaign as '
      'clean GitHub-flavored Markdown. Start with a level-1 title exactly: '
      '"$title". Then use "##" section headings in this order: Campaign Overview, '
      'Campaign Summary, Crop Images Reviewed, Image Analysis Findings, '
      'Soil Moisture & Current Condition, Field Map / GPS Context, Risk Level, '
      'Farmer Recommendations, Action Plan, Missing Data, Safety Note. '
      'Use ONLY the real values from the context (real disease findings, '
      'confidence, severity, counts, and the supplemental field values). Do not '
      'invent diseases or sensor readings. List anything unavailable under '
      'Missing Data. Give practical farmer steps; for chemical treatment, advise '
      'following the product label and a local agriculture expert (no exact '
      'pesticide dosages). Keep it farmer-friendly.';

  final resp = await ref.read(aiAssistantServiceProvider).chat(
        message: instruction,
        appContext: campaign.fullAiContext,
      );

  final markdown = resp.answer.trim().isEmpty
      ? '# $title\n\n_The report could not be generated. Please try again._'
      : resp.answer;

  final reportJson = <String, dynamic>{
    'campaign_name': campaign.name,
    'crop_type': campaign.cropType,
    'source': campaign.source,
    'image_count': campaign.imageCount,
    'analyzed_count': campaign.analyzedCount,
    'disease_count': campaign.diseaseCount,
    if (campaign.summaryStats != null) 'summary_stats': campaign.summaryStats,
    if (campaign.env != null) 'env': campaign.env,
  };

  try {
    final row = await ref.read(supabaseServiceProvider).saveReport(
          reportType: 'campaign',
          title: title,
          reportMarkdown: markdown,
          reportJson: reportJson,
          campaignId: campaign.manualId,
          flightId: null,
        );
    ref.invalidate(reportsProvider);
    return CropReport.fromRow(row);
  } catch (_) {
    return CropReport(
      id: 'unsaved',
      reportType: 'campaign',
      title: title,
      reportMarkdown: markdown,
      reportJson: reportJson,
      campaignId: campaign.manualId,
      flightId: null,
      createdAt: DateTime.now(),
    );
  }
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
  // Manual campaigns with persisted Image Analysis (and supplemental field
  // context) get a richer, campaign-wide report generated from the full real
  // context via the AI Advisor, instead of a single-detection report.
  if (!campaign.isDroneFlight && campaign.supplemental != null) {
    return _generateCampaignReportFromContext(ref, campaign);
  }

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
