import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/flight_path_point.dart';

/// Interactive map pin representing a single drone flight capture location.
class FlightMarker extends StatelessWidget {
  final FlightPathPoint point;
  final Color flightColor;
  final bool isSelected;
  final VoidCallback onTap;

  const FlightMarker({
    super.key,
    required this.point,
    required this.flightColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double size = isSelected ? 36.0 : 24.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Outer Ring / Glowing Selection Border
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.bg,
                  border: Border.all(
                    color: isSelected ? AppColors.green : flightColor,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.green.withAlpha((255 * 0.40).toInt()),
                            blurRadius: 10.0,
                            spreadRadius: 2.0,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha((255 * 0.50).toInt()),
                            blurRadius: 4.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  // Inner Core
                  child: Container(
                    width: size * 0.45,
                    height: size * 0.45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.green : flightColor.withAlpha((255 * 0.30).toInt()),
                    ),
                  ),
                ),
              ),

              // AI Processed (Disease Detection Indicator Badge) in top corner
              if (point.aiProcessed && !point.rejected)
                Positioned(
                  top: -2.0,
                  right: -2.0,
                  child: Container(
                    width: isSelected ? 10.0 : 8.0,
                    height: isSelected ? 10.0 : 8.0,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.crit, // disease warning red/coral dot
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.crit,
                          blurRadius: 4.0,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),

              // Blurry / Rejected Blur Indicator Badge (Red X overlay in center)
              if (point.rejected)
                Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.close,
                      color: AppColors.crit,
                      size: size * 0.75,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2.0,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
