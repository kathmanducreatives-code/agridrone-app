/// Model representing a single flight capture from the `flight_captures` table.
class FlightCapture {
  final int id;
  final int flightId;
  final int imageIndex;
  final String deviceId;
  final String? imagePath;
  final String? imageUrl;
  final int? moistureRaw;
  final double? moisturePct;
  final int? capturedAtMs;
  final DateTime? uploadedAt;
  final bool aiProcessed;
  final bool reviewed;
  final bool rejected;
  final DateTime? analysisRequestedAt;

  const FlightCapture({
    required this.id,
    required this.flightId,
    required this.imageIndex,
    required this.deviceId,
    this.imagePath,
    this.imageUrl,
    this.moistureRaw,
    this.moisturePct,
    this.capturedAtMs,
    this.uploadedAt,
    required this.aiProcessed,
    required this.reviewed,
    required this.rejected,
    this.analysisRequestedAt,
  });

  factory FlightCapture.fromJson(Map<String, dynamic> json) {
    final rawImageUrl = json['image_url'] as String?;
    String? resolvedImageUrl = rawImageUrl;
    if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
      resolvedImageUrl = (rawImageUrl.startsWith('http://') || rawImageUrl.startsWith('https://'))
          ? rawImageUrl
          : 'https://luvostyizefajbltukkc.supabase.co/storage/v1/object/public/drone-images/${rawImageUrl.startsWith('/') ? rawImageUrl.substring(1) : rawImageUrl}';
    }

    return FlightCapture(
      id: json['id'] as int,
      flightId: json['flight_id'] as int,
      imageIndex: json['image_index'] as int,
      deviceId: json['device_id'] as String? ?? 'unknown',
      imagePath: json['image_path'] as String?,
      imageUrl: resolvedImageUrl,
      moistureRaw: json['moisture_raw'] as int?,
      moisturePct: (json['moisture_pct'] as num?)?.toDouble(),
      capturedAtMs: (json['captured_at_ms'] as num?)?.toInt(),
      uploadedAt: json['uploaded_at'] != null ? DateTime.tryParse(json['uploaded_at'] as String) : null,
      aiProcessed: json['ai_processed'] as bool? ?? false,
      reviewed: json['reviewed'] as bool? ?? false,
      rejected: json['rejected'] as bool? ?? false,
      analysisRequestedAt: json['analysis_requested_at'] != null
          ? DateTime.tryParse(json['analysis_requested_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flight_id': flightId,
      'image_index': imageIndex,
      'device_id': deviceId,
      'image_path': imagePath,
      'image_url': imageUrl,
      'moisture_raw': moistureRaw,
      'moisture_pct': moisturePct,
      'captured_at_ms': capturedAtMs,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'ai_processed': aiProcessed,
      'reviewed': reviewed,
      'rejected': rejected,
      'analysis_requested_at': analysisRequestedAt?.toIso8601String(),
    };
  }

  // Derived state for curation dashboard UI
  bool get isPending  => !reviewed;
  bool get isSelected => reviewed && !rejected && analysisRequestedAt == null;
  bool get isAnalyzed => aiProcessed;

  FlightCapture copyWith({
    int? id,
    int? flightId,
    int? imageIndex,
    String? deviceId,
    String? imagePath,
    String? imageUrl,
    int? moistureRaw,
    double? moisturePct,
    int? capturedAtMs,
    DateTime? uploadedAt,
    bool? aiProcessed,
    bool? reviewed,
    bool? rejected,
    DateTime? Function()? analysisRequestedAt,
  }) {
    return FlightCapture(
      id: id ?? this.id,
      flightId: flightId ?? this.flightId,
      imageIndex: imageIndex ?? this.imageIndex,
      deviceId: deviceId ?? this.deviceId,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      moistureRaw: moistureRaw ?? this.moistureRaw,
      moisturePct: moisturePct ?? this.moisturePct,
      capturedAtMs: capturedAtMs ?? this.capturedAtMs,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      aiProcessed: aiProcessed ?? this.aiProcessed,
      reviewed: reviewed ?? this.reviewed,
      rejected: rejected ?? this.rejected,
      analysisRequestedAt: analysisRequestedAt != null ? analysisRequestedAt() : this.analysisRequestedAt,
    );
  }
}
