import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/detection.dart';
import '../theme/app_colors.dart';
import 'glass_card.dart';
import 'bbox_overlay.dart';

/// Card widget to display a single detection item with thumbnail, overlay, and confidence.
class DetectionCard extends StatelessWidget {
  final Detection detection;
  final VoidCallback? onTap;

  const DetectionCard({
    super.key,
    required this.detection,
    this.onTap,
  });

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 5) return 'just now';
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = detection.imageUrl ?? '';

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bounding-box overlaid thumbnail (200x150)
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: SizedBox(
              width: 140.0, // adjusted layout size for responsive fit
              height: 105.0,
              child: BboxOverlay(
                detections: [detection],
                showLabels: true,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.surface2,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.surface2,
                          child: const Icon(Icons.broken_image, color: AppColors.crit),
                        ),
                      )
                    : Container(
                        color: AppColors.surface2,
                        child: const Icon(Icons.image, color: AppColors.textDim),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16.0),
          // Info details
          Expanded(
            child: SizedBox(
              height: 105.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Disease badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: detection.color.withAlpha((255 * 0.15).toInt()),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: detection.color, width: 1.0),
                        ),
                        child: Text(
                          detection.displayLabel.toUpperCase(),
                          style: TextStyle(
                            color: detection.color,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Space Grotesk',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        'Flight FLT_${detection.flightId.toString().padLeft(4, '0')}',
                        style: const TextStyle(
                          color: AppColors.textDim,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      Text(
                        'Image Index #${detection.imageIndex}',
                        style: const TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 11.0,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'CONFIDENCE',
                            style: TextStyle(
                              color: AppColors.textFaint,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Space Grotesk',
                            ),
                          ),
                          Text(
                            detection.confidencePercent,
                            style: TextStyle(
                              color: detection.color,
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: LinearProgressIndicator(
                          value: detection.confidence,
                          backgroundColor: AppColors.surface2,
                          valueColor: AlwaysStoppedAnimation<Color>(detection.color),
                          minHeight: 4.0,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _formatTimeAgo(detection.detectedAt),
                      style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 10.0,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
