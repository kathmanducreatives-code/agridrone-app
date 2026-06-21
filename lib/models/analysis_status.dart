/// Stable lifecycle labels for crop image analysis.
///
/// Phase 1 keeps compatibility with the existing `ai_processed` boolean.
/// These values are ready for a later `analysis_status` database column.
enum AnalysisStatus {
  uploaded,
  reviewPending,
  analysisRequested,
  queued,
  processing,
  detected,
  noDetection,
  failed,
  explained,
}

extension AnalysisStatusValue on AnalysisStatus {
  String get value {
    switch (this) {
      case AnalysisStatus.uploaded:
        return 'uploaded';
      case AnalysisStatus.reviewPending:
        return 'review_pending';
      case AnalysisStatus.analysisRequested:
        return 'analysis_requested';
      case AnalysisStatus.queued:
        return 'queued';
      case AnalysisStatus.processing:
        return 'processing';
      case AnalysisStatus.detected:
        return 'detected';
      case AnalysisStatus.noDetection:
        return 'no_detection';
      case AnalysisStatus.failed:
        return 'failed';
      case AnalysisStatus.explained:
        return 'explained';
    }
  }
}
