import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/status_dot.dart';
import '../widgets/detection_card.dart';
import '../models/detection.dart';
import '../providers/flight_providers.dart';
import '../providers/realtime_providers.dart';
import '../services/realtime_service.dart';
import 'analytics_screen.dart'; // To reuse the LabDetailsModal on card taps!

/// Live Feed Screen showing vertical scrolling live disease card streams prepended as they arrive.
class DroneScreen extends ConsumerStatefulWidget {
  const DroneScreen({super.key});

  @override
  ConsumerState<DroneScreen> createState() => _DroneScreenState();
}

class _DroneScreenState extends ConsumerState<DroneScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Detection> _currentDetections = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final realtime = ref.read(realtimeServiceProvider);
      _subscription = realtime.detectionInserts.listen((json) {
        final newDetection = Detection.fromJson(json);
        _insertDetection(newDetection);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _insertDetection(Detection det) {
    if (!mounted) return;
    setState(() {
      _currentDetections.insert(0, det);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 500));
    });
  }

  void _openDetailModal(BuildContext context, Detection det) {
    // Queries capture data details to pass to modal dialog
    ref.read(supabaseServiceProvider).getCaptures(flightId: det.flightId).then((captures) {
      if (captures.isNotEmpty && mounted) {
        final match = captures.firstWhere((c) => c.imageIndex == det.imageIndex, orElse: () => captures.first);
        showDialog(
          context: context,
          barrierColor: Colors.black.withAlpha((255 * 0.85).toInt()),
          builder: (_) => LabDetailsModal(
            capture: match,
            detections: [det],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final liveDetections = ref.watch(liveDetectionsProvider);
    final count60s = ref.watch(liveDetectionsLast60sCountProvider);
    final connStateAsync = ref.watch(realtimeConnectionProvider);

    // Sync live provider details with internal list state
    if (_currentDetections.isEmpty && liveDetections.isNotEmpty) {
      _currentDetections.addAll(liveDetections);
    }

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIVE INFECTION FEED',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontSize: 20.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          StatusDot(color: connectionColor, size: 8.0),
                          const SizedBox(width: 8.0),
                          Text(
                            '$count60s ANALYSES IN LAST 60S',
                            style: GoogleFonts.jetBrainsMono(
                              color: AppColors.textDim,
                              fontSize: 11.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: AppColors.line, width: 1.0),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textDim, size: 20.0),
                      onPressed: () {
                        ref.read(liveDetectionsProvider.notifier).clear();
                        setState(() {
                          _currentDetections.clear();
                        });
                      },
                      tooltip: 'Clear session feed',
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24.0),

              // Activity dots history strip
              if (_currentDetections.isNotEmpty) ...[
                _buildActivityStrip(context, _currentDetections),
                const SizedBox(height: 16.0),
              ],

              // Card stream list
              Expanded(
                child: _currentDetections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StatusDot(color: connectionColor, size: 16.0),
                            const SizedBox(height: 16.0),
                            Text(
                              'No analyses yet — head to Lab to start analyzing drone images.',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.textDim,
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : AnimatedList(
                        key: _listKey,
                        initialItemCount: _currentDetections.length,
                        itemBuilder: (context, index, animation) {
                          if (index >= _currentDetections.length) return const SizedBox.shrink();
                          final detection = _currentDetections[index];

                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.25),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                            child: FadeTransition(
                              opacity: animation,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: DetectionCard(
                                  detection: detection,
                                  onTap: () => _openDetailModal(context, detection),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityStrip(BuildContext context, List<Detection> list) {
    final dots = list.take(25).toList().reversed.toList();
    return Container(
      height: 24.0,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: dots.map((d) {
          return GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text(
                    '${d.displayLabel} (${d.confidencePercent}) · Flight ${d.flightId} #${d.imageIndex}',
                    style: GoogleFonts.spaceGrotesk(color: d.color, fontWeight: FontWeight.bold),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                margin: const EdgeInsets.only(right: 6.0),
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  color: d.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: d.color.withAlpha((255 * 0.4).toInt()),
                      blurRadius: 4.0,
                      spreadRadius: 1.0,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
