class DetectionItem {
  final int id;
  final int flightCaptureId;
  final int flightId;
  final int imageIndex;
  final String label;
  final double confidence;
  final double? bboxX1;
  final double? bboxY1;
  final double? bboxX2;
  final double? bboxY2;
  final int? inferenceTimeMs;
  final DateTime detectedAt;

  DetectionItem({
    required this.id,
    required this.flightCaptureId,
    required this.flightId,
    required this.imageIndex,
    required this.label,
    required this.confidence,
    this.bboxX1,
    this.bboxY1,
    this.bboxX2,
    this.bboxY2,
    this.inferenceTimeMs,
    required this.detectedAt,
  });

  factory DetectionItem.fromJson(Map<String, dynamic> json) {
    return DetectionItem(
      id: json['id'] as int,
      flightCaptureId: json['flight_capture_id'] as int,
      flightId: json['flight_id'] as int,
      imageIndex: json['image_index'] as int,
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      bboxX1: (json['bbox_x1'] as num?)?.toDouble(),
      bboxY1: (json['bbox_y1'] as num?)?.toDouble(),
      bboxX2: (json['bbox_x2'] as num?)?.toDouble(),
      bboxY2: (json['bbox_y2'] as num?)?.toDouble(),
      inferenceTimeMs: json['inference_time_ms'] as int?,
      detectedAt: json['detected_at'] != null
          ? DateTime.parse(json['detected_at'] as String)
          : DateTime.now(),
    );
  }

  String get formattedLabel => label.replaceAll('_', ' ').toUpperCase();

  String get severity {
    if (confidence >= 0.75) return 'HIGH';
    if (confidence >= 0.45) return 'MEDIUM';
    return 'LOW';
  }
}
