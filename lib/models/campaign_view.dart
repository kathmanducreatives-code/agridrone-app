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
  });

  /// Build a manual campaign from a `campaigns` row plus computed real counts.
  factory CampaignView.fromManual(
    Map<String, dynamic> row, {
    required int imageCount,
    required int analyzedCount,
    required int diseaseCount,
  }) {
    final id = row['id'] as String;
    return CampaignView(
      id: 'manual:$id',
      name: (row['name'] as String?)?.trim().isNotEmpty == true
          ? row['name'] as String
          : 'Untitled campaign',
      source: 'manual',
      cropType: row['crop_type'] as String?,
      fieldName: row['field_name'] as String?,
      manualId: id,
      notes: row['notes'] as String?,
      imageCount: imageCount,
      analyzedCount: analyzedCount,
      diseaseCount: diseaseCount,
      reportAvailable: false,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
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
  Map<String, dynamic> toAdvisorCampaign() => {
        'name': name,
        'source': source,
        if (cropType != null) 'crop_type': cropType,
        if (fieldName != null) 'field_name': fieldName,
        'image_count': imageCount,
        'analyzed_count': analyzedCount,
        'disease_count': diseaseCount,
        'report_available': reportAvailable,
      };

  /// Context object sent to the AI Advisor as `selected_flight`.
  Map<String, dynamic>? toAdvisorFlight() {
    if (flightId == null) return null;
    return {'id': 'FLT_${flightId.toString().padLeft(4, '0')}'};
  }
}
