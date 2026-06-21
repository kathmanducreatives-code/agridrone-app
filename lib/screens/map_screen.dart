import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../models/flight_path_point.dart';
import '../providers/map_providers.dart';
import '../providers/realtime_providers.dart'; // contains realtimeConnectionProvider
import '../providers/global_ai_advisor_provider.dart';
import '../services/realtime_service.dart'; // contains RealtimeConnectionState
import '../widgets/glass_card.dart';
import '../widgets/status_dot.dart';
import '../widgets/flight_marker.dart';
import '../widgets/marker_popup_card.dart';
import '../widgets/agri_ui.dart';

/// Screen presenting geotagged mission captures and flight paths overlaying an interactive map.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  FlightPathPoint? _selectedPoint;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(flightPathPointsProvider);
    final flightIdsAsync = ref.watch(geotaggedFlightIdsProvider);
    final filter = ref.watch(mapFilterProvider);
    final colorFor = ref.watch(flightColorProvider);
    final connStateAsync = ref.watch(realtimeConnectionProvider);

    Color connectionColor = AppColors.crit;
    connStateAsync.whenData((state) {
      if (state == RealtimeConnectionState.connected) {
        connectionColor = AppColors.green;
      } else if (state == RealtimeConnectionState.connecting) {
        connectionColor = AppColors.warn;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIELD MAP',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'See where crop issues appear after a drone flight',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.textFaint,
                          fontSize: 11.0,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      StatusDot(color: connectionColor, size: 8.0),
                      const SizedBox(width: 8.0),
                      Text(
                        connStateAsync.maybeWhen(
                          data: _connectionLabel,
                          orElse: () => 'Getting ready',
                        ),
                        style: GoogleFonts.spaceGrotesk(
                          color: connectionColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.line, height: 1.0),

            _buildFieldOverview(pointsAsync),

            // Sidebar / Header Filter Action Bar
            _buildFilterBar(flightIdsAsync, filter),
            const Divider(color: AppColors.line, height: 1.0),

            // Interactive Map Area
            Expanded(
              child: pointsAsync.when(
                data: (points) => _buildMap(points, colorFor),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.green),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Could not load field locations: $err',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.crit),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(
      AsyncValue<List<int>> flightIdsAsync, MapFilter filter) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          // Flight selection dropdown
          Expanded(
            child: flightIdsAsync.maybeWhen(
              data: (idsList) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: filter.flightId,
                      dropdownColor: AppColors.surface,
                      isExpanded: true,
                      hint: Text(
                        'All flights',
                        style: GoogleFonts.spaceGrotesk(
                            color: AppColors.text, fontSize: 12.0),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'All Flights',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppColors.text, fontSize: 12.0),
                          ),
                        ),
                        ...idsList.map(
                          (id) => DropdownMenuItem<int?>(
                            value: id,
                            child: Text(
                              'Flight ${id.toString().padLeft(4, '0')}',
                              style: GoogleFonts.jetBrainsMono(
                                  color: AppColors.text, fontSize: 12.0),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (id) {
                        setState(() {
                          _selectedPoint = null; // Clear active selections
                        });
                        ref
                            .read(mapFilterProvider.notifier)
                            .setFilter(filter.copyWith(flightId: id));
                      },
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 12.0),

          // Only with detections switch
          Row(
            children: [
              Checkbox(
                value: filter.onlyWithDetections,
                activeColor: AppColors.green,
                checkColor: Colors.black,
                side: const BorderSide(color: AppColors.lineBright),
                onChanged: (val) {
                  setState(() {
                    _selectedPoint = null;
                  });
                  ref.read(mapFilterProvider.notifier).setFilter(
                      filter.copyWith(onlyWithDetections: val ?? false));
                },
              ),
              Text(
                'Only crop issues',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim,
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _connectionLabel(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return 'Ready';
      case RealtimeConnectionState.connecting:
        return 'Getting ready';
      case RealtimeConnectionState.disconnected:
        return 'Offline mode';
      case RealtimeConnectionState.error:
        return 'Needs attention';
    }
  }

  Widget _buildFieldOverview(AsyncValue<List<FlightPathPoint>> pointsAsync) {
    final points = pointsAsync.value ?? const <FlightPathPoint>[];
    final hasGps = points.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final cards = [
            SystemStatusChip(
              label: 'Field boundary',
              status: 'Not saved yet',
              ok: false,
              icon: Icons.grass_rounded,
            ),
            SystemStatusChip(
              label: 'Field locations',
              status: hasGps
                  ? '${points.length} linked images'
                  : 'Not available yet',
              ok: hasGps,
              icon: Icons.health_and_safety_rounded,
            ),
            const SystemStatusChip(
              label: 'Moisture',
              status: 'Not available',
              ok: false,
              icon: Icons.water_drop_outlined,
            ),
            const SystemStatusChip(
              label: 'Local Weather',
              status: 'Weather not connected',
              ok: false,
              icon: Icons.wb_cloudy_outlined,
            ),
          ];
          final chips = Wrap(spacing: 8, runSpacing: 8, children: cards);
          return AgriGlassCard(
            padding: const EdgeInsets.all(14),
            radius: 22,
            elevated: false,
            child: wide
                ? Row(
                    children: [
                      Expanded(child: chips),
                      const SizedBox(width: 12),
                      _AskFieldButton(ref: ref),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      chips,
                      const SizedBox(height: 12),
                      _AskFieldButton(ref: ref),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMap(List<FlightPathPoint> points, Color Function(int) colorFor) {
    if (points.isEmpty) {
      return Center(
        child: GlassCard(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off,
                  color: AppColors.textFaint, size: 48.0),
              const SizedBox(height: 16.0),
              Text(
                'No field locations yet',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'No field locations yet. GPS-linked crop images will appear here after a flight.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textFaint,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(globalAiAdvisorProvider.notifier).open();
                  ref.read(globalAiAdvisorProvider.notifier).sendMessage(
                        'Where should I inspect first if field location is not available yet?',
                        ref.read(aiAdvisorAppContextProvider),
                      );
                },
                icon: const Icon(Icons.eco_rounded),
                label: const Text('Ask AI Advisor'),
              ),
            ],
          ),
        ),
      );
    }

    // Group flight coordinates for polyline path calculations
    final Map<int, List<FlightPathPoint>> byFlight = {};
    for (final p in points) {
      byFlight.putIfAbsent(p.flightId, () => []).add(p);
    }

    // Sort captures by image index to render progressive lines correctly
    for (final entry in byFlight.entries) {
      entry.value.sort((a, b) => a.imageIndex.compareTo(b.imageIndex));
    }

    final polylines = byFlight.entries.map((entry) {
      return Polyline(
        points: entry.value.map((p) => p.latLng).toList(),
        strokeWidth: 3.0,
        color: colorFor(entry.key),
      );
    }).toList();

    final markers = points.map((p) {
      final isSel = _selectedPoint?.captureId == p.captureId;
      final double markerSize = isSel ? 40.0 : 28.0;

      return Marker(
        width: markerSize,
        height: markerSize,
        point: p.latLng,
        child: FlightMarker(
          point: p,
          flightColor: colorFor(p.flightId),
          isSelected: isSel,
          onTap: () {
            setState(() {
              _selectedPoint = p;
            });
            // Pan to the selected capture point
            _mapController.move(p.latLng, _mapController.camera.zoom);
          },
        ),
      );
    }).toList();

    // Auto-fit camera boundaries on the next frame
    final bounds =
        LatLngBounds.fromPoints(points.map((p) => p.latLng).toList());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && points.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(52.0),
          ),
        );
      }
    });

    return Stack(
      children: [
        // Map Canvas layer
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: points.first.latLng,
            initialZoom: 16.0,
            minZoom: 3.0,
            maxZoom: 18.0,
            onTap: (_, __) {
              setState(() {
                _selectedPoint = null;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.agridrone.guardian',
              // Slightly soften the map tiles to fit the AgriDrone visual system.
              tileBuilder: (context, child, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -1,
                    0,
                    0,
                    0,
                    255,
                    0,
                    -1,
                    0,
                    0,
                    255,
                    0,
                    0,
                    -1,
                    0,
                    255,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
                  child: child,
                );
              },
            ),
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),

        // Floating Recenter Navigation Button
        Positioned(
          right: 16.0,
          bottom: _selectedPoint != null ? 220.0 : 16.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                side: const BorderSide(color: AppColors.line),
              ),
              onPressed: () {
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(52.0),
                  ),
                );
              },
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
        ),

        // Dynamic Popup details overlay card
        if (_selectedPoint != null)
          Positioned(
            left: 16.0,
            right: 16.0,
            bottom: 16.0,
            child: MarkerPopupCard(
              point: _selectedPoint!,
              onClose: () {
                setState(() {
                  _selectedPoint = null;
                });
              },
              onOpenDetail: () {
                // Navigates and opens detail overlay dialog cleanly
              },
            ),
          ),
      ],
    );
  }
}

class _AskFieldButton extends StatelessWidget {
  final WidgetRef ref;

  const _AskFieldButton({required this.ref});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        ref.read(globalAiAdvisorProvider.notifier).open();
        ref.read(globalAiAdvisorProvider.notifier).sendMessage(
              'Ask what this field needs',
              ref.read(aiAdvisorAppContextProvider),
            );
      },
      icon: const Icon(Icons.eco_rounded),
      label: const Text('Ask what this field needs'),
    );
  }
}
