import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight_capture.dart';
import 'flight_providers.dart';

/// State representation of the sequential AI inference process in progress.
class AnalysisProgress {
  final int total;
  final int completed;
  final int failed;
  final List<Map<String, dynamic>> results;
  final bool isComplete;
  final bool isRunning;

  const AnalysisProgress({
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.results = const [],
    this.isComplete = false,
    this.isRunning = false,
  });

  AnalysisProgress copyWith({
    int? total,
    int? completed,
    int? failed,
    List<Map<String, dynamic>>? results,
    bool? isComplete,
    bool? isRunning,
  }) {
    return AnalysisProgress(
      total: total ?? this.total,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      results: results ?? this.results,
      isComplete: isComplete ?? this.isComplete,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

/// Notifier driving the sequential AI execution flow.
class AnalysisProgressNotifier extends Notifier<AnalysisProgress> {
  @override
  AnalysisProgress build() => const AnalysisProgress();

  /// Iterates sequentially through selected flight captures, performing RPC requests and FastAPI predictions.
  Future<void> runAnalysis(List<FlightCapture> selectedList) async {
    state = AnalysisProgress(
      total: selectedList.length,
      isRunning: true,
    );

    final supabase = ref.read(supabaseServiceProvider);
    final huggingface = ref.read(huggingFaceServiceProvider);

    for (int i = 0; i < selectedList.length; i++) {
      final cap = selectedList[i];
      try {
        // 1. Call RPC markReviewed (bypasses RLS to update reviewed/analysis_requested_at)
        await supabase.requestAnalysis(cap.id);

        // 2. Call FastAPI predict webhook
        final response = await huggingface.predict(
          imageUrl: cap.imageUrl ?? '',
          flightCaptureId: cap.id,
          flightId: cap.flightId,
          imageIndex: cap.imageIndex,
        );

        final newResults = List<Map<String, dynamic>>.from(state.results)..add({
          'capture': cap,
          'success': true,
          'detections': response['detections'] ?? [],
          'inference_time_ms': response['inference_time_ms'] ?? 0.0,
        });

        state = state.copyWith(
          completed: state.completed + 1,
          results: newResults,
        );
      } catch (e) {
        final newResults = List<Map<String, dynamic>>.from(state.results)..add({
          'capture': cap,
          'success': false,
          'error': e.toString(),
        });

        state = state.copyWith(
          failed: state.failed + 1,
          results: newResults,
        );
      }
    }

    state = state.copyWith(
      isComplete: true,
      isRunning: false,
    );
  }

  /// Resets progressive state tracker.
  void reset() => state = const AnalysisProgress();
}

/// Provider managing active sequential analysis states.
final analysisProgressProvider = NotifierProvider<AnalysisProgressNotifier, AnalysisProgress>(
  AnalysisProgressNotifier.new,
);
