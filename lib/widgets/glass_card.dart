import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable Glassmorphism card widget with BackdropFilter blur and custom border/glow states.
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
                  color: AppColors.green.withAlpha((255 * 0.35).toInt()),
                  blurRadius: 12.0,
                  spreadRadius: -2.0,
                )
              ]
            : null,
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
