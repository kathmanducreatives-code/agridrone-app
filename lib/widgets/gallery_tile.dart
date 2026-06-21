import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/flight_capture.dart';
import '../models/detection.dart';
import '../theme/app_colors.dart';

/// Gallery grid tile widget representing a single drone flight capture with curation states.
class GalleryTile extends StatelessWidget {
  final FlightCapture capture;
  final bool isSelected;
  final List<Detection> detections;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GalleryTile({
    super.key,
    required this.capture,
    required this.isSelected,
    required this.detections,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = capture.imageUrl ?? '';

    // Curation visual states determination
    final bool isRejected = capture.reviewed && capture.rejected;
    final bool isAnalyzed = capture.aiProcessed;

    // Outer border color selection
    Color borderColor = AppColors.line;
    double borderWidth = 1.0;
    double scale = 1.0;

    if (isSelected) {
      borderColor = AppColors.selected;
      borderWidth = 2.0;
      scale = 1.02; // slight upscale for selected state
    } else if (isRejected) {
      borderColor = AppColors.rejected.withAlpha((255 * 0.4).toInt());
    } else if (isAnalyzed) {
      borderColor = AppColors.analyzed;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scaleByDouble(scale, scale, scale, 1.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Opacity(
        opacity: isRejected ? 0.4 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.0),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail image background
                imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.green),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surface2,
                          child: const Icon(Icons.broken_image,
                              color: AppColors.crit),
                        ),
                      )
                    : Container(color: AppColors.surface),

                // Subtle dark overlay gradient for pill text legibility
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.2),
                          Color.fromRGBO(0, 0, 0, 0.0),
                          Color.fromRGBO(0, 0, 0, 0.7),
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),

                // Info Strip (Flight # index, moisture)
                Positioned(
                  bottom: detections.isNotEmpty || isAnalyzed ? 32.0 : 10.0,
                  left: 10.0,
                  right: 10.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FLT_${capture.flightId} #${capture.imageIndex}',
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.text,
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        capture.moisturePct != null
                            ? '${capture.moisturePct!.toStringAsFixed(0)}% soil'
                            : '—',
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.textDim,
                          fontSize: 10.0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Analyzed labels bottom pill chips
                if (isAnalyzed)
                  Positioned(
                    bottom: 8.0,
                    left: 8.0,
                    right: 8.0,
                    child: SizedBox(
                      height: 18.0,
                      child: detections.isEmpty
                          ? Text(
                              'CLEAN CANOPY',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.greenLime,
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : ListView(
                              scrollDirection: Axis.horizontal,
                              children: detections.map((d) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 4.0),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0, vertical: 1.0),
                                  decoration: BoxDecoration(
                                    color:
                                        d.color.withAlpha((255 * 0.15).toInt()),
                                    borderRadius: BorderRadius.circular(4.0),
                                    border:
                                        Border.all(color: d.color, width: 0.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      d.displayLabel.toUpperCase(),
                                      style: TextStyle(
                                        color: d.color,
                                        fontSize: 7.0,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Space Grotesk',
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),

                // State status badges (Top Right position)
                Positioned(
                  top: 8.0,
                  right: 8.0,
                  child: _buildStateBadge(isRejected, isAnalyzed, isSelected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateBadge(bool isRejected, bool isAnalyzed, bool isSelected) {
    if (isSelected) {
      return Container(
        padding: const EdgeInsets.all(4.0),
        decoration: const BoxDecoration(
            color: AppColors.selected, shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.black, size: 12.0),
      );
    }
    if (isRejected) {
      return Container(
        padding: const EdgeInsets.all(4.0),
        decoration: const BoxDecoration(
            color: AppColors.rejected, shape: BoxShape.circle),
        child: const Icon(Icons.close, color: Colors.black, size: 12.0),
      );
    }
    if (isAnalyzed) {
      return Container(
        padding: const EdgeInsets.all(4.0),
        decoration: const BoxDecoration(
            color: AppColors.analyzed, shape: BoxShape.circle),
        child:
            const Icon(Icons.radar_outlined, color: Colors.black, size: 12.0),
      );
    }
    return const SizedBox.shrink();
  }
}
