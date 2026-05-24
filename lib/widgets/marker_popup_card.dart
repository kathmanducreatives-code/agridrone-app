import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_colors.dart';
import '../models/flight_path_point.dart';
import '../models/detection.dart';
import '../models/flight_capture.dart';
import '../providers/flight_providers.dart'; // contains supabaseServiceProvider
import '../screens/analytics_screen.dart'; // contains LabDetailsModal
import '../widgets/glass_card.dart';

/// Provider querying crop detections recorded on a specific capture point.
final captureDetectionsProvider = FutureProvider.family<List<Detection>, int>((ref, captureId) async {
  return ref.watch(supabaseServiceProvider).getDetectionsForCapture(captureId);
});

/// Responsive overlay presenting detailed metadata popup cards on the map.
class MarkerPopupCard extends ConsumerWidget {
  final FlightPathPoint point;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;

  const MarkerPopupCard({
    super.key,
    required this.point,
    required this.onClose,
    required this.onOpenDetail,
  });

  void _showCurationDetails(BuildContext context, WidgetRef ref, List<Detection> detections) {
    // Dynamically build a FlightCapture from the FlightPathPoint
    final capture = FlightCapture(
      id: point.captureId,
      flightId: point.flightId,
      imageIndex: point.imageIndex,
      deviceId: 'drone-gps',
      imageUrl: point.imageUrl,
      uploadedAt: point.uploadedAt,
      aiProcessed: point.aiProcessed,
      reviewed: true,
      rejected: point.rejected,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((255 * 0.85).toInt()),
      builder: (_) => LabDetailsModal(
        capture: capture,
        detections: detections,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detectionsAsync = ref.watch(captureDetectionsProvider(point.captureId));
    final String imageUrl = point.imageUrl ?? '';

    return GlassCard(
      bright: true,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Close and Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FLIGHT FLT_${point.flightId.toString().padLeft(4, '0')} · IDX #${point.imageIndex}',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textDim, size: 16.0),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // Main Card Content Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Thumbnail Widget
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: SizedBox(
                  width: 100.0,
                  height: 75.0,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 1.5),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.broken_image, color: AppColors.textFaint, size: 24.0),
                          ),
                        )
                      : Container(color: AppColors.surface),
                ),
              ),
              const SizedBox(width: 12.0),

              // Metadata Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coordinates Log Row
                    Text(
                      'LAT ${point.lat.toStringAsFixed(5)} · LON ${point.lon.toStringAsFixed(5)}',
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.textDim,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4.0),

                    // Altitude & Satellite Log Row
                    Text(
                      'ALT ${point.altitudeM != null ? '${point.altitudeM!.toStringAsFixed(1)}m' : 'N/A'} · FIX ${point.gpsFixQuality} · SAT ${point.gpsSatellites ?? '—'}',
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.textFaint,
                        fontSize: 9.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),

                    // Detections status line
                    detectionsAsync.when(
                      data: (detections) {
                        if (detections.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft.withAlpha((255 * 0.12).toInt()),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              'CLEAN CANOPY',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.greenSoft,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        // Display detection chips
                        return Wrap(
                          spacing: 4.0,
                          runSpacing: 4.0,
                          children: detections.map((d) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: d.color.withAlpha((255 * 0.12).toInt()),
                                borderRadius: BorderRadius.circular(4.0),
                                border: Border.all(color: d.color.withAlpha((255 * 0.35).toInt()), width: 0.5),
                              ),
                              child: Text(
                                d.displayLabel.toUpperCase(),
                                style: GoogleFonts.spaceGrotesk(
                                  color: d.color,
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 10.0,
                        width: 10.0,
                        child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 1.0),
                      ),
                      error: (err, _) => Text(
                        'Failed to load threat reports',
                        style: GoogleFonts.spaceGrotesk(color: AppColors.crit, fontSize: 9.0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // Detail Opener Button
          detectionsAsync.maybeWhen(
            data: (detections) => ElevatedButton.icon(
              onPressed: () {
                onOpenDetail();
                _showCurationDetails(context, ref, detections);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(36.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.open_in_new, size: 14.0),
              label: Text(
                'OPEN FULL CURATION ENVELOPE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            orElse: () => const ElevatedButton(
              onPressed: null,
              child: SizedBox(
                height: 14.0,
                width: 14.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
