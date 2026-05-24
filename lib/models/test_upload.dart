/// Model representing a single user test upload from the `test_uploads` table and view.
class TestUpload {
  final int id;
  final String uploadUuid;
  final String? sourceFilename;
  final String imageUrl;
  final int? imageSizeBytes;
  final String uploadedBy;
  final DateTime uploadedAt;
  final DateTime? analysisRequestedAt;
  final bool aiProcessed;
  final String? notes;

  // From test_upload_summary view (optional joined fields)
  final int? detectionCount;
  final String? labelsFound;
  final double? maxConfidence;

  const TestUpload({
    required this.id,
    required this.uploadUuid,
    this.sourceFilename,
    required this.imageUrl,
    this.imageSizeBytes,
    required this.uploadedBy,
    required this.uploadedAt,
    this.analysisRequestedAt,
    required this.aiProcessed,
    this.notes,
    this.detectionCount,
    this.labelsFound,
    this.maxConfidence,
  });

  factory TestUpload.fromJson(Map<String, dynamic> json) {
    final rawImageUrl = json['image_url'] as String? ?? '';
    String resolvedImageUrl = rawImageUrl;
    if (rawImageUrl.isNotEmpty) {
      resolvedImageUrl = (rawImageUrl.startsWith('http://') || rawImageUrl.startsWith('https://'))
          ? rawImageUrl
          : 'https://luvostyizefajbltukkc.supabase.co/storage/v1/object/public/drone-images/${rawImageUrl.startsWith('/') ? rawImageUrl.substring(1) : rawImageUrl}';
    }

    return TestUpload(
      id: json['id'] as int,
      uploadUuid: json['upload_uuid'] as String? ?? '',
      sourceFilename: json['source_filename'] as String?,
      imageUrl: resolvedImageUrl,
      imageSizeBytes: json['image_size_bytes'] as int?,
      uploadedBy: json['uploaded_by'] as String? ?? 'web-operator',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : DateTime.now(),
      analysisRequestedAt: json['analysis_requested_at'] != null
          ? DateTime.parse(json['analysis_requested_at'] as String)
          : null,
      aiProcessed: json['ai_processed'] as bool? ?? false,
      notes: json['notes'] as String?,
      detectionCount: json['detection_count'] as int?,
      labelsFound: json['labels_found'] as String?,
      maxConfidence: (json['max_confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'upload_uuid': uploadUuid,
      'source_filename': sourceFilename,
      'image_url': imageUrl,
      'image_size_bytes': imageSizeBytes,
      'uploaded_by': uploadedBy,
      'uploaded_at': uploadedAt.toIso8601String(),
      'analysis_requested_at': analysisRequestedAt?.toIso8601String(),
      'ai_processed': aiProcessed,
      'notes': notes,
      'detection_count': detectionCount,
      'labels_found': labelsFound,
      'max_confidence': maxConfidence,
    };
  }

  TestUpload copyWith({
    int? id,
    String? uploadUuid,
    String? sourceFilename,
    String? imageUrl,
    int? imageSizeBytes,
    String? uploadedBy,
    DateTime? uploadedAt,
    DateTime? Function()? analysisRequestedAt,
    bool? aiProcessed,
    String? notes,
    int? detectionCount,
    String? labelsFound,
    double? maxConfidence,
  }) {
    return TestUpload(
      id: id ?? this.id,
      uploadUuid: uploadUuid ?? this.uploadUuid,
      sourceFilename: sourceFilename ?? this.sourceFilename,
      imageUrl: imageUrl ?? this.imageUrl,
      imageSizeBytes: imageSizeBytes ?? this.imageSizeBytes,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      analysisRequestedAt: analysisRequestedAt != null ? analysisRequestedAt() : this.analysisRequestedAt,
      aiProcessed: aiProcessed ?? this.aiProcessed,
      notes: notes ?? this.notes,
      detectionCount: detectionCount ?? this.detectionCount,
      labelsFound: labelsFound ?? this.labelsFound,
      maxConfidence: maxConfidence ?? this.maxConfidence,
    );
  }
}
