import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Model representing a single disease bounding box detection recorded on a test upload.
class TestDetection {
  final int id;
  final int testUploadId;
  final String label;
  final double confidence;
  final double? bboxX1;
  final double? bboxY1;
  final double? bboxX2;
  final double? bboxY2;
  final double? inferenceTimeMs;
  final DateTime detectedAt;

  const TestDetection({
    required this.id,
    required this.testUploadId,
    required this.label,
    required this.confidence,
    this.bboxX1,
    this.bboxY1,
    this.bboxX2,
    this.bboxY2,
    this.inferenceTimeMs,
    required this.detectedAt,
  });

  factory TestDetection.fromJson(Map<String, dynamic> json) {
    return TestDetection(
      id: json['id'] as int,
      testUploadId: json['test_upload_id'] as int,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'test_upload_id': testUploadId,
      'label': label,
      'confidence': confidence,
      'bbox_x1': bboxX1,
      'bbox_y1': bboxY1,
      'bbox_x2': bboxX2,
      'bbox_y2': bboxY2,
      'inference_time_ms': inferenceTimeMs,
      'detected_at': detectedAt.toIso8601String(),
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
