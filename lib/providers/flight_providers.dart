import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight_capture.dart';
import '../models/flight_summary.dart';
import '../models/detection.dart';
import '../services/huggingface_service.dart';
import '../services/supabase_service.dart';
import 'realtime_providers.dart';

// ── Service singletons ───────────────────────────────────────

/// Provider exposing the Supabase query service layer.
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Provider exposing the HuggingFace model webhook services.
final huggingFaceServiceProvider = Provider<HuggingFaceService>((ref) {
  return HuggingFaceService();
});

// ── Flight summary providers ───────────────────────────────

/// FutureProvider supplying aggregated summaries for all drone flights.
final allFlightsProvider = FutureProvider<List<FlightSummary>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);
  
  final sub1 = realtime.captureInserts.listen((_) => ref.invalidateSelf());
  final sub2 = realtime.captureUpdates.listen((_) => ref.invalidateSelf());
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
  });

  return service.getAllFlights();
});

/// FutureProvider supplying aggregated metrics of the single latest flight.
final latestFlightSummaryProvider = FutureProvider<FlightSummary?>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);
  
  final sub1 = realtime.captureInserts.listen((_) => ref.invalidateSelf());
  final sub2 = realtime.captureUpdates.listen((_) => ref.invalidateSelf());
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
  });

  return service.getLatestFlightSummary();
});

// ── Captures list providers ────────────────────────────────

/// Family FutureProvider to query captures for a specific flight, listening to updates.
final flightCapturesProvider = FutureProvider.family<List<FlightCapture>, int>((ref, flightId) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  final sub1 = realtime.captureInserts.listen((event) {
    if (event['flight_id'] == flightId) {
      ref.invalidateSelf();
    }
  });
  final sub2 = realtime.captureUpdates.listen((event) {
    if (event['flight_id'] == flightId) {
      ref.invalidateSelf();
    }
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
  });

  return service.getCaptures(flightId: flightId);
});

/// FutureProvider supplying all captures across all missions.
final allFlightCapturesProvider = FutureProvider<List<FlightCapture>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  final sub1 = realtime.captureInserts.listen((_) => ref.invalidateSelf());
  final sub2 = realtime.captureUpdates.listen((_) => ref.invalidateSelf());
  
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
  });

  return service.getCaptures();
});

// ── Detections list providers ──────────────────────────────

/// Family FutureProvider to fetch disease detections recorded during a flight.
final detectionsForFlightProvider = FutureProvider.family<List<Detection>, int>((ref, flightId) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  final sub = realtime.detectionInserts.listen((event) {
    if (event['flight_id'] == flightId) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(() => sub.cancel());

  return service.getDetectionsForFlight(flightId);
});

/// FutureProvider to fetch all detections, listening for real-time insert events.
final allDetectionsProvider = FutureProvider<List<Detection>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  final sub = realtime.detectionInserts.listen((_) => ref.invalidateSelf());
  ref.onDispose(() => sub.cancel());

  return service.getAllDetections();
});

// ── Live Stream Feed ───────────────────────────────────────

/// Notifier maintaining the live dashboard stream of detections.
class LiveDetectionsNotifier extends Notifier<List<Detection>> {
  StreamSubscription? _subscription;

  @override
  List<Detection> build() {
    final realtime = ref.watch(realtimeServiceProvider);

    // Initial load from standard database view query
    ref.read(supabaseServiceProvider).getRecentDetections(limit: 50).then((initialList) {
      state = initialList;
    });

    // Subscribes to new detections INSERT in Postgres
    _subscription = realtime.detectionInserts.listen((json) {
      final newDetection = Detection.fromJson(json);
      // Prepend newest first, and cap the list at 50 elements
      state = [newDetection, ...state].take(50).toList();
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return [];
  }

  /// Reset the feed (e.g. for testing purposes)
  void clear() {
    state = [];
  }

  void setDetections(List<Detection> list) {
    state = list;
  }
}

/// Provider for the live streaming list of detections.
final liveDetectionsProvider = NotifierProvider<LiveDetectionsNotifier, List<Detection>>(
  LiveDetectionsNotifier.new,
);

/// Provider exposing the count of detections added to the stream in the last 60 seconds.
final liveDetectionsLast60sCountProvider = Provider<int>((ref) {
  final detections = ref.watch(liveDetectionsProvider);
  final now = DateTime.now();
  final sixtySecondsAgo = now.subtract(const Duration(seconds: 60));
  return detections.where((d) => d.detectedAt.isAfter(sixtySecondsAgo)).length;
});
