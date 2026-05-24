import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flight_capture.dart';
import '../models/detection.dart';
import '../models/flight_summary.dart';
import '../models/flight_path_point.dart';

/// Central database access layer executing queries and RPC curation changes against Supabase.
class SupabaseService {
  final _client = Supabase.instance.client;

  /// Fetches the summary of the latest flight, ordered by upload activity.
  Future<FlightSummary?> getLatestFlightSummary() async {
    try {
      final res = await _client
          .from('flight_summary')
          .select()
          .order('last_uploaded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return FlightSummary.fromJson(res);
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching latest flight summary: $e');
      return null;
    }
  }

  /// Fetches summaries of all flights.
  Future<List<FlightSummary>> getAllFlights() async {
    try {
      final res = await _client
          .from('flight_summary')
          .select()
          .order('last_uploaded_at', ascending: false);
      return (res as List).map((j) => FlightSummary.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching all flight summaries: $e');
      return [];
    }
  }

  /// Queries flight capture files filtered by various parameters.
  Future<List<FlightCapture>> getCaptures({
    int? flightId,
    bool? reviewed,
    bool? rejected,
    bool? aiProcessed,
    int limit = 200,
  }) async {
    try {
      var query = _client.from('flight_captures').select();
      if (flightId != null) query = query.eq('flight_id', flightId);
      if (reviewed != null) query = query.eq('reviewed', reviewed);
      if (rejected != null) query = query.eq('rejected', rejected);
      if (aiProcessed != null) query = query.eq('ai_processed', aiProcessed);

      final res = await query
          .order('uploaded_at', ascending: false)
          .limit(limit);
      return (res as List).map((j) => FlightCapture.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching captures: $e');
      return [];
    }
  }

  /// Queries all crop infections registered under a specific capture row.
  Future<List<Detection>> getDetectionsForCapture(int captureId) async {
    try {
      final res = await _client
          .from('detections')
          .select()
          .eq('flight_capture_id', captureId)
          .order('detected_at', ascending: true);
      return (res as List).map((j) => Detection.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching detections for capture $captureId: $e');
      return [];
    }
  }

  /// Queries all crop disease detections registered under a specific flight.
  Future<List<Detection>> getDetectionsForFlight(int flightId) async {
    try {
      final res = await _client
          .from('detections')
          .select()
          .eq('flight_id', flightId)
          .order('image_index', ascending: true);
      return (res as List).map((j) => Detection.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching detections for FLT_$flightId: $e');
      return [];
    }
  }

  /// Fetches recent detections with joined URL details from `latest_detections` view.
  Future<List<Detection>> getRecentDetections({int limit = 50}) async {
    try {
      final res = await _client
          .from('latest_detections')
          .select()
          .order('detected_at', ascending: false)
          .limit(limit);
      return (res as List).map((j) => Detection.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching recent detections: $e');
      return [];
    }
  }

  /// Fetches all detections from the detections table.
  Future<List<Detection>> getAllDetections({int limit = 1000}) async {
    try {
      final res = await _client
          .from('detections')
          .select()
          .order('detected_at', ascending: false)
          .limit(limit);
      return (res as List).map((j) => Detection.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching all detections: $e');
      return [];
    }
  }

  /// Fetches the total count of captures awaiting operator review.
  Future<int> getPendingReviewCount() async {
    try {
      final res = await _client
          .from('flight_captures')
          .select('id')
          .eq('reviewed', false);
      return (res as List).length;
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching pending review count: $e');
      return 0;
    }
  }

  /// Fetches the count of captures analyzed today (last 24 hours).
  Future<int> getAnalyzedTodayCount() async {
    try {
      final timestamp = DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String();
      final res = await _client
          .from('flight_captures')
          .select('id')
          .eq('ai_processed', true)
          .gte('analysis_requested_at', timestamp);
      return (res as List).length;
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching analyzed today count: $e');
      return 0;
    }
  }

  /// Fetches the count of crop infections recorded in the last 24 hours.
  Future<int> getTodayDetectionsCount() async {
    try {
      final timestamp = DateTime.now().subtract(const Duration(hours: 24)).toUtc().toIso8601String();
      final res = await _client
          .from('detections')
          .select('id')
          .gte('detected_at', timestamp);
      return (res as List).length;
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching today detections count: $e');
      return 0;
    }
  }

  /// Groups successfully analyzed captures by day to populate weekly charts.
  Future<List<Map<String, dynamic>>> getDailyAnalyzedCounts(int days) async {
    try {
      final timestamp = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();
      final res = await _client
          .from('flight_captures')
          .select('analysis_requested_at')
          .eq('ai_processed', true)
          .gte('analysis_requested_at', timestamp);
      
      final List data = res as List;
      final Map<String, int> counts = {};
      
      final now = DateTime.now();
      for (int i = days - 1; i >= 0; i--) {
        final localDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final dateKey = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
        counts[dateKey] = 0;
      }

      for (final item in data) {
        final analysisRequestedStr = item['analysis_requested_at'] as String?;
        if (analysisRequestedStr != null) {
          final parsedDate = DateTime.tryParse(analysisRequestedStr);
          if (parsedDate != null) {
            final localDate = parsedDate.toLocal();
            final dateKey = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
            if (counts.containsKey(dateKey)) {
              counts[dateKey] = counts[dateKey]! + 1;
            }
          }
        }
      }

      return counts.entries.map((e) => {
        'date': e.key,
        'count': e.value,
      }).toList()..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    } catch (e) {
      debugPrint('[AgriDrone] Error calculating daily analyzed counts: $e');
      return [];
    }
  }

  /// RPC call bypassing read-only RLS via SECURITY DEFINER to mark a capture reviewed or rejected.
  Future<void> markReviewed(int captureId, {required bool rejected}) async {
    debugPrint('[AgriDrone] RPC markReviewed on capture: $captureId, rejected: $rejected');
    await _client.rpc('mark_capture_reviewed', params: {
      'capture_id': captureId,
      'is_rejected': rejected,
    });
  }

  /// RPC call bypassing read-only RLS via SECURITY DEFINER to mark capture selection for AI inference.
  Future<void> requestAnalysis(int captureId) async {
    debugPrint('[AgriDrone] RPC requestAnalysis on capture: $captureId');
    await _client.rpc('request_capture_analysis', params: {
      'capture_id': captureId,
    });
  }

  /// Fetches a list of flight path captures with GPS coordinates from flight_paths view.
  Future<List<FlightPathPoint>> getFlightPathPoints({int? flightId}) async {
    try {
      var query = _client.from('flight_paths').select();
      if (flightId != null) {
        query = query.eq('flight_id', flightId);
      }
      final res = await query.order('flight_id').order('image_index');
      return (res as List).map((j) => FlightPathPoint.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching flight path points: $e');
      return [];
    }
  }

  /// Distinct flight IDs that have at least one geotagged capture.
  Future<List<int>> getGeotaggedFlightIds() async {
    try {
      final res = await _client
          .from('flight_paths')
          .select('flight_id');
      final ids = (res as List).map((j) => j['flight_id'] as int).toSet().toList()..sort();
      return ids;
    } catch (e) {
      debugPrint('[AgriDrone] Error fetching geotagged flight IDs: $e');
      return [];
    }
  }
}
