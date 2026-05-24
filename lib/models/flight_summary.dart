/// Model representing aggregated metadata for a single flight from the `flight_summary` view.
class FlightSummary {
  final int flightId;
  final String deviceId;
  final int imageCount;
  final int pendingReview;
  final int rejectedCount;
  final int analyzedCount;
  final double? avgMoisturePct;
  final int? startedAtMs;
  final int? endedAtMs;
  final int totalDetections;
  final int uniqueDiseases;
  final bool fullyProcessed;
  final DateTime? lastUploadedAt;

  const FlightSummary({
    required this.flightId,
    required this.deviceId,
    required this.imageCount,
    required this.pendingReview,
    required this.rejectedCount,
    required this.analyzedCount,
    this.avgMoisturePct,
    this.startedAtMs,
    this.endedAtMs,
    required this.totalDetections,
    required this.uniqueDiseases,
    required this.fullyProcessed,
    this.lastUploadedAt,
  });

  factory FlightSummary.fromJson(Map<String, dynamic> json) {
    return FlightSummary(
      flightId: json['flight_id'] as int,
      deviceId: json['device_id'] as String? ?? 'unknown',
      imageCount: json['image_count'] as int? ?? 0,
      pendingReview: json['pending_review'] as int? ?? 0,
      rejectedCount: json['rejected_count'] as int? ?? 0,
      analyzedCount: json['analyzed_count'] as int? ?? 0,
      avgMoisturePct: (json['avg_moisture_pct'] as num?)?.toDouble(),
      startedAtMs: (json['started_at_ms'] as num?)?.toInt(),
      endedAtMs: (json['ended_at_ms'] as num?)?.toInt(),
      totalDetections: json['total_detections'] as int? ?? 0,
      uniqueDiseases: json['unique_diseases'] as int? ?? 0,
      fullyProcessed: json['fully_processed'] as bool? ?? false,
      lastUploadedAt: json['last_uploaded_at'] != null
          ? DateTime.tryParse(json['last_uploaded_at'] as String)
          : null,
    );
  }
}
