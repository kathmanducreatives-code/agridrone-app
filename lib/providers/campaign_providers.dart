import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/campaign_view.dart';
import '../models/detection.dart';
import '../models/flight_capture.dart';
import 'flight_providers.dart';

/// All drone-flight campaigns, derived from the real `flight_summary` data.
final flightCampaignsProvider =
    FutureProvider<List<CampaignView>>((ref) async {
  final flights = await ref.watch(allFlightsProvider.future);
  final campaigns = flights.map(CampaignView.fromFlight).toList();
  campaigns.sort(_byCreatedDesc);
  return campaigns;
});

/// Active campaign-image links for a specific manual campaign.
final campaignImagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, campaignId) async {
  return ref
      .watch(supabaseServiceProvider)
      .getActiveCampaignImages(campaignId: campaignId);
});

/// All manual campaigns from the `campaigns` table, with real counts computed
/// from the linked captures/detections. Returns an empty list (not an error)
/// if the campaigns table does not exist yet, so the UI stays graceful.
final manualCampaignsProvider =
    FutureProvider<List<CampaignView>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);

  List<Map<String, dynamic>> rows;
  List<Map<String, dynamic>> links;
  try {
    rows = await service.getManualCampaigns();
    links = await service.getActiveCampaignImages();
  } catch (_) {
    // Table not set up yet (migration pending) — show no manual campaigns.
    return const [];
  }
  if (rows.isEmpty) return const [];

  final captures = await ref.watch(allFlightCapturesProvider.future);
  final detections = await ref.watch(allDetectionsProvider.future);

  final captureById = {for (final c in captures) c.id: c};
  final detectionCaptureIds = <int>{for (final d in detections) d.flightCaptureId};

  // Group active image links by campaign.
  final linksByCampaign = <String, List<Map<String, dynamic>>>{};
  for (final l in links) {
    final cid = l['campaign_id'] as String?;
    if (cid == null) continue;
    (linksByCampaign[cid] ??= []).add(l);
  }

  final result = <CampaignView>[];
  for (final row in rows) {
    final id = row['id'] as String;
    final imgs = linksByCampaign[id] ?? const [];
    var analyzed = 0;
    var disease = 0;
    for (final l in imgs) {
      final captureId = (l['capture_id'] as num?)?.toInt();
      if (captureId == null) continue;
      final cap = captureById[captureId];
      if (cap != null && cap.aiProcessed) analyzed++;
      if (detectionCaptureIds.contains(captureId)) disease++;
    }
    result.add(CampaignView.fromManual(
      row,
      imageCount: imgs.length,
      analyzedCount: analyzed,
      diseaseCount: disease,
    ));
  }
  result.sort(_byCreatedDesc);
  return result;
});

/// Combined campaign list: manual campaigns first (newest), then drone flights.
final allCampaignsProvider = FutureProvider<List<CampaignView>>((ref) async {
  final manual = await ref.watch(manualCampaignsProvider.future);
  final flights = await ref.watch(flightCampaignsProvider.future);
  return [...manual, ...flights];
});

/// Resolves the FlightCapture objects + detections backing a manual campaign's
/// assigned (capture-linked) images.
class ManualCampaignContents {
  final List<FlightCapture> captures;
  final List<Detection> detections;
  const ManualCampaignContents(this.captures, this.detections);
}

final manualCampaignContentsProvider =
    FutureProvider.family<ManualCampaignContents, String>(
        (ref, campaignId) async {
  final links = await ref.watch(campaignImagesProvider(campaignId).future);
  final captures = await ref.watch(allFlightCapturesProvider.future);
  final detections = await ref.watch(allDetectionsProvider.future);

  final captureIds = <int>{
    for (final l in links)
      if (l['capture_id'] != null) (l['capture_id'] as num).toInt(),
  };
  final caps =
      captures.where((c) => captureIds.contains(c.id)).toList();
  final dets =
      detections.where((d) => captureIds.contains(d.flightCaptureId)).toList();
  return ManualCampaignContents(caps, dets);
});

int _byCreatedDesc(CampaignView a, CampaignView b) {
  final ad = a.createdAt;
  final bd = b.createdAt;
  if (ad == null && bd == null) return b.id.compareTo(a.id);
  if (ad == null) return 1;
  if (bd == null) return -1;
  return bd.compareTo(ad);
}

/// The campaign currently opened in the Campaigns tab (null = show the list).
/// Kept as a tab-local selection so the global AI Advisor overlay stays mounted.
class SelectedCampaignNotifier extends Notifier<CampaignView?> {
  @override
  CampaignView? build() => null;

  void open(CampaignView campaign) => state = campaign;
  void clear() => state = null;
}

final selectedFlightCampaignProvider =
    NotifierProvider<SelectedCampaignNotifier, CampaignView?>(
  SelectedCampaignNotifier.new,
);
