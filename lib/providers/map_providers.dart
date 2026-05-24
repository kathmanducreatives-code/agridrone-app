import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flight_path_point.dart';
import '../providers/flight_providers.dart'; // contains supabaseServiceProvider

/// Holds filtering configurations for the GPS Flight Geography map viewer.
class MapFilter {
  final int? flightId; // null = all flights
  final bool onlyWithDetections;

  const MapFilter({
    this.flightId,
    this.onlyWithDetections = false,
  });

  MapFilter copyWith({
    int? flightId,
    bool? onlyWithDetections,
  }) {
    return MapFilter(
      flightId: flightId ?? this.flightId,
      onlyWithDetections: onlyWithDetections ?? this.onlyWithDetections,
    );
  }
}

/// Notifier class managing active map filter state changes.
class MapFilterNotifier extends Notifier<MapFilter> {
  @override
  MapFilter build() => const MapFilter();

  void setFilter(MapFilter filter) {
    state = filter;
  }
}

/// Provider managing active map filter settings.
final mapFilterProvider = NotifierProvider<MapFilterNotifier, MapFilter>(MapFilterNotifier.new);

/// FutureProvider querying all distinct flight IDs that have GPS telemetry.
final geotaggedFlightIdsProvider = FutureProvider<List<int>>((ref) async {
  return ref.watch(supabaseServiceProvider).getGeotaggedFlightIds();
});

/// FutureProvider querying and filtering flight path captures according to current filters.
final flightPathPointsProvider = FutureProvider<List<FlightPathPoint>>((ref) async {
  final filter = ref.watch(mapFilterProvider);
  final points = await ref.watch(supabaseServiceProvider).getFlightPathPoints(
        flightId: filter.flightId,
      );

  if (!filter.onlyWithDetections) {
    return points;
  }

  // Filter captures to only those successfully processed and containing at least one infection detection.
  // (We filter in-memory since the list size is typically small to medium)
  return points.where((p) => p.aiProcessed && !p.rejected).toList();
});

/// Provider mapping flight IDs to unique distinctive aesthetic theme colors for polyline differentiation.
final flightColorProvider = Provider<Color Function(int)>((ref) {
  const palette = [
    Color(0xFF00FF88), // Neon Green
    Color(0xFF5AD7FF), // Neon Cyan
    Color(0xFFAAFF00), // Lime Green
    Color(0xFFFFD700), // Golden Yellow
    Color(0xFFFFB547), // Deep Orange
    Color(0xFFFF5577), // Neon Coral
  ];
  return (int flightId) => palette[flightId % palette.length];
});
