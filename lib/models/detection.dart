import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Model representing a single crop disease detection bounding box.
class Detection {
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
  final double? inferenceTimeMs;
  final DateTime detectedAt;
  final String? imageUrl; // Joined from latest_detections view

  const Detection({
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
    this.imageUrl,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    final rawImageUrl = json['image_url'] as String?;
    String? resolvedImageUrl = rawImageUrl;
    if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
      resolvedImageUrl = (rawImageUrl.startsWith('http://') || rawImageUrl.startsWith('https://'))
          ? rawImageUrl
          : 'https://luvostyizefajbltukkc.supabase.co/storage/v1/object/public/drone-images/${rawImageUrl.startsWith('/') ? rawImageUrl.substring(1) : rawImageUrl}';
    }

    return Detection(
      id: json['id'] as int,
      flightCaptureId: json['flight_capture_id'] as int,
      flightId: json['flight_id'] as int,
      imageIndex: json['image_index'] as int,
      label: json['label'] as String? ?? 'Unknown',
      confidence: (json['confidence'] as num? ?? 0.0).toDouble(),
      bboxX1: (json['bbox_x1'] as num?)?.toDouble(),
      bboxY1: (json['bbox_y1'] as num?)?.toDouble(),
      bboxX2: (json['bbox_x2'] as num?)?.toDouble(),
      bboxY2: (json['bbox_y2'] as num?)?.toDouble(),
      inferenceTimeMs: (json['inference_time_ms'] as num?)?.toDouble(),
      detectedAt: json['detected_at'] != null
          ? DateTime.parse(json['detected_at'] as String)
          : DateTime.now(),
      imageUrl: resolvedImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flight_capture_id': flightCaptureId,
      'flight_id': flightId,
      'image_index': imageIndex,
      'label': label,
      'confidence': confidence,
      'bbox_x1': bboxX1,
      'bbox_y1': bboxY1,
      'bbox_x2': bboxX2,
      'bbox_y2': bboxY2,
      'inference_time_ms': inferenceTimeMs,
      'detected_at': detectedAt.toIso8601String(),
      'image_url': imageUrl,
    };
  }

  Color get color => AppColors.diseaseColors[label] ?? AppColors.green;
  String get displayLabel {
    final clean = label.replaceAll('_', ' ').toLowerCase();
    if (clean.contains('rice blast') || clean.contains('rice_blast') || clean == 'rice blast disease') {
      return 'धानको ब्लास्ट रोग (Rice Blast)';
    }
    if (clean.contains('brown spot') || clean.contains('rice_brown_spot') || clean == 'brown spot disease') {
      return 'ब्राउन स्पट रोग (Brown Spot)';
    }
    if (clean.contains('stem borer') || clean.contains('gabaro') || clean.contains('borer')) {
      return 'गवारो किरा (Gabaro/Stem Borer)';
    }
    if (clean.contains('khaira')) {
      return 'खैरा रोग (Khaira Disease)';
    }
    if (clean.contains('narrow brown spot')) {
      return 'न्यारो ब्राउन स्पट (Narrow Brown)';
    }
    if (clean.contains('dirty panicle')) {
      return 'डर्टी प्यानिकल रोग (Dirty Panicle)';
    }
    return label.replaceAll('_', ' ');
  }
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
