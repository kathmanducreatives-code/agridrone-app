import 'dart:convert';

import 'flight_summary.dart';

/// Presentation model for a Crop Campaign.
///
/// A campaign groups crop images, an optional drone flight, diagnoses and a
/// report. There are two sources:
///  - `drone_flight`  — derived from a real flight in `flight_captures`.
///  - `manual`        — created by the farmer (persisted once the campaigns
///                      table migration has been applied).
///
/// Drone-flight campaigns are "virtual": all numbers come straight from the
/// real `flight_summary` aggregates, so nothing here is fabricated.
class CampaignView {
  /// Stable id, e.g. `flight:49` for a drone-flight campaign.
  final String id;
  final String name;

  /// 'drone_flight' or 'manual'.
  final String source;
  final String? cropType;
  final String? fieldName;

  /// Underlying flight id for drone-flight campaigns (null for manual).
  final int? flightId;

  /// Underlying campaigns-table uuid for manual campaigns (null for flight).
  final String? manualId;

  final String? notes;

  final int imageCount;
  final int analyzedCount;

  /// Real disease detections recorded for this campaign (0 = not analysed /
  /// no findings yet — never invent a disease here).
  final int diseaseCount;

  final bool reportAvailable;
  final DateTime? createdAt;

  /// Parsed supplemental data stored in `campaigns.notes` (env context +
  /// persisted Image Analysis results + summary stats). Null when absent.
  /// Environmental values here are supplemental demo defaults; disease results
  /// are real Image Analysis model outputs.
  final Map<String, dynamic>? supplemental;

  const CampaignView({
    required this.id,
    required this.name,
    required this.source,
    this.cropType,
    this.fieldName,
    this.flightId,
    this.manualId,
    this.notes,
    required this.imageCount,
    required this.analyzedCount,
    required this.diseaseCount,
    this.reportAvailable = false,
    this.createdAt,
    this.supplemental,
  });

  /// Environmental context (soil moisture, temperature, weather, GPS, zone).
  Map<String, dynamic>? get env {
    final e = supplemental?['env'];
    return e is Map ? Map<String, dynamic>.from(e) : null;
  }

  /// Per-image-id Image Analysis results persisted for this campaign.
  Map<String, dynamic> get imageAnalysis {
    final a = supplemental?['image_analysis'];
    return a is Map ? Map<String, dynamic>.from(a) : const {};
  }

  Map<String, dynamic>? get summaryStats {
    final s = supplemental?['summary_stats'];
    return s is Map ? Map<String, dynamic>.from(s) : null;
  }

  static Map<String, dynamic>? _parseNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(notes);
      if (decoded is Map &&
          decoded['schema'] == 'agri_campaign_supplemental_v1') {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {/* plain-text notes — not supplemental JSON */}
    return null;
  }

  /// Build a manual campaign from a `campaigns` row plus computed real counts.
  factory CampaignView.fromManual(
    Map<String, dynamic> row, {
    required int imageCount,
    required int analyzedCount,
    required int diseaseCount,
  }) {
    final id = row['id'] as String;
    final supplemental = _parseNotes(row['notes'] as String?);
    final stats = supplemental?['summary_stats'];
    final env = supplemental?['env'];

    // Persisted Image Analysis results (from notes) are the source of truth for
    // analyzed / disease counts when present, since manual device uploads have
    // no flight-capture detections to count.
    var effectiveAnalyzed = analyzedCount;
    var effectiveDisease = diseaseCount;
    if (stats is Map) {
      final a = (stats['analyzed_images'] as num?)?.toInt();
      final d = (stats['diseased_images'] as num?)?.toInt();
      if (a != null) effectiveAnalyzed = a;
      if (d != null) effectiveDisease = d;
    }

    String? effectiveField = row['field_name'] as String?;
    if ((effectiveField == null || effectiveField.trim().isEmpty) &&
        env is Map &&
        env['field_name'] is String) {
      effectiveField = env['field_name'] as String;
    }

    return CampaignView(
      id: 'manual:$id',
      name: (row['name'] as String?)?.trim().isNotEmpty == true
          ? row['name'] as String
          : 'Untitled campaign',
      source: 'manual',
      cropType: row['crop_type'] as String?,
      fieldName: effectiveField,
      manualId: id,
      notes: row['notes'] as String?,
      imageCount: imageCount,
      analyzedCount: effectiveAnalyzed,
      diseaseCount: effectiveDisease,
      reportAvailable: false,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      supplemental: supplemental,
    );
  }

  /// Build a virtual campaign from a real flight summary.
  factory CampaignView.fromFlight(FlightSummary f) {
    final padded = f.flightId.toString().padLeft(4, '0');
    return CampaignView(
      id: 'flight:${f.flightId}',
      name: 'Flight FLT_$padded',
      source: 'drone_flight',
      cropType: null, // flight_summary view carries no crop type
      fieldName: null,
      flightId: f.flightId,
      imageCount: f.imageCount,
      analyzedCount: f.analyzedCount,
      diseaseCount: f.totalDetections,
      reportAvailable: false, // no real flight report exists yet
      createdAt: f.lastUploadedAt,
    );
  }

  bool get isDroneFlight => source == 'drone_flight';
  String get sourceLabel => isDroneFlight ? 'Drone Flight' : 'Manual Upload';

  /// A real crop report can only be generated once real analysed images exist.
  bool get canGenerateReport => analyzedCount > 0;

  bool get hasDiagnosis => diseaseCount > 0;

  /// Context object sent to the AI Advisor as `selected_campaign`.
  Map<String, dynamic> toAdvisorCampaign() {
    final stats = summaryStats;
    return {
      'id': manualId ?? id,
      'name': name,
      'source': source,
      if (cropType != null) 'crop_type': cropType,
      if (fieldName != null) 'field_name': fieldName,
      'image_count': imageCount,
      'analyzed_count': analyzedCount,
      'disease_count': diseaseCount,
      if (stats?['healthy_images'] != null)
        'healthy_count': stats!['healthy_images'],
      if (stats?['needs_review'] != null)
        'needs_review': stats!['needs_review'],
      'report_available': reportAvailable,
    };
  }

  /// Per-image analysis flattened for the AI (no URLs needed for reasoning).
  List<Map<String, dynamic>> get aiCampaignImages {
    final out = <Map<String, dynamic>>[];
    imageAnalysis.forEach((id, v) {
      if (v is! Map) return;
      final a = Map<String, dynamic>.from(v);
      out.add({
        'id': id,
        'analysis_status': a['analyzed'] == true ? 'analyzed' : 'pending',
        if (a['health_status'] != null) 'health_status': a['health_status'],
        if (a['disease_name'] != null) 'disease_name': a['disease_name'],
        if (a['confidence'] != null) 'confidence': a['confidence'],
        if (a['severity'] != null) 'severity': a['severity'],
        'needs_review': a['needs_review'] ?? false,
      });
    });
    return out;
  }

  /// Full `app_context` extras for this campaign (selected_campaign +
  /// campaign_images + summary/weather/soil/field/report contexts).
  Map<String, dynamic> get fullAiExtras => toAdvisorExtras(aiCampaignImages);

  /// A complete, self-contained `app_context` for AI calls about this campaign.
  Map<String, dynamic> get fullAiContext => {
        'current_page': 'Campaign Detail',
        'user_mode': 'farmer',
        ...fullAiExtras,
      };

  /// Full AI context extras for this campaign (env-derived contexts + summary).
  /// `campaignImages` (per-image analysis with urls) is supplied by the caller
  /// because the URLs live in `campaign_images`, not on this model.
  Map<String, dynamic> toAdvisorExtras(List<Map<String, dynamic>> campaignImages) {
    final s = supplemental;
    final out = <String, dynamic>{
      'selected_campaign': toAdvisorCampaign(),
      'campaign_images': campaignImages,
    };
    if (s == null) return out;
    if (s['summary_stats'] is Map) out['summary_stats'] = s['summary_stats'];
    if (s['weather_context'] is Map) out['weather_context'] = s['weather_context'];
    if (s['soil_moisture_context'] is Map) {
      out['soil_moisture_context'] = s['soil_moisture_context'];
    }
    if (s['field_context'] is Map) out['field_context'] = s['field_context'];
    out['report_context'] = {'latest_report_available': reportAvailable};
    return out;
  }

  /// Context object sent to the AI Advisor as `selected_flight`.
  Map<String, dynamic>? toAdvisorFlight() {
    if (flightId == null) return null;
    return {'id': 'FLT_${flightId.toString().padLeft(4, '0')}'};
  }
}
