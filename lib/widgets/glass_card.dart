import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable light glassmorphism card widget with soft SaaS depth.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool bright;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.bright = false,
    this.borderRadius = 18.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bright ? AppColors.glassHi : AppColors.glass,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: bright ? AppColors.lineBright : AppColors.line,
          width: bright ? 1.5 : 1.0,
        ),
        boxShadow: bright
            ? [
                BoxShadow(
                  color: AppColors.greenDeep.withAlpha((255 * 0.10).toInt()),
                  blurRadius: 24.0,
                  offset: const Offset(0, 12),
                  spreadRadius: -6.0,
                )
              ]
            : [
                BoxShadow(
                  color: AppColors.greenDeep.withAlpha((255 * 0.06).toInt()),
                  blurRadius: 18.0,
                  offset: const Offset(0, 10),
                  spreadRadius: -8.0,
                ),
              ],
      ),
      child: child,
    );

    final blurredCard = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: cardContent,
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: blurredCard,
        ),
      );
    }
    return blurredCard;
  }
}
