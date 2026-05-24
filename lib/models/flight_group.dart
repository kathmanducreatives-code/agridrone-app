import 'flight_capture.dart';

/// Groups [FlightCapture]s that share the same [flightId].
class FlightGroup {
  final int flightId;
  final String deviceId;
  final List<FlightCapture> captures;

  const FlightGroup({
    required this.flightId,
    required this.deviceId,
    required this.captures,
  });

  // ── Computed properties ────────────────────────────────────

  int get totalCount => captures.length;

  int get processedCount =>
      captures.where((c) => c.aiProcessed).length;

  bool get fullyProcessed =>
      totalCount > 0 && processedCount == totalCount;

  double get processingProgress =>
      totalCount == 0 ? 0.0 : processedCount / totalCount;

  /// Most recent capture timestamp in the group.
  DateTime? get latestCaptureTime {
    DateTime? latest;
    for (final c in captures) {
      if (c.uploadedAt != null) {
        if (latest == null || c.uploadedAt!.isAfter(latest)) {
          latest = c.uploadedAt;
        }
      }
    }
    return latest;
  }

  /// First image URL for thumbnail / preview display.
  String? get thumbnailUrl =>
      captures.isNotEmpty ? captures.first.imageUrl : null;
}
