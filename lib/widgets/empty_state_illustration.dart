import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'agri_ui.dart';

/// A rich empty-state widget with a local illustration image, title, message,
/// and an optional call-to-action button.
///
/// Use this instead of icon-only empty states to give the app a premium,
/// polished, illustration-rich feel.
class EmptyStateIllustration extends StatelessWidget {
  final String imagePath;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double imageHeight;

  const EmptyStateIllustration({
    super.key,
    required this.imagePath,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.imageHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              imagePath,
              height: imageHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(
                height: imageHeight,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_rounded,
                    color: AppColors.textFaint,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
