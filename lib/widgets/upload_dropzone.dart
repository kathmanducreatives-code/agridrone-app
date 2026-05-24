import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../providers/test_upload_providers.dart';

/// Reusable dashed-border interactive picker zone.
/// Combines file picker actions with the dark cyber-agri aesthetic.
class UploadDropzone extends StatefulWidget {
  final void Function(List<PendingFile>) onFilesPicked;
  final bool compact;

  const UploadDropzone({
    super.key,
    required this.onFilesPicked,
    this.compact = false,
  });

  @override
  State<UploadDropzone> createState() => _UploadDropzoneState();
}

class _UploadDropzoneState extends State<UploadDropzone> {
  bool _isHovered = false;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: true, // Crucial for Web to load bytes in memory
      );

      if (result == null || result.files.isEmpty) return;

      final List<PendingFile> pickedFiles = [];
      for (final file in result.files) {
        var bytes = file.bytes;
        // On non-web platform, bytes might be null if not loaded automatically. Read from path.
        if (bytes == null && file.path != null && !kIsWeb) {
          bytes = io.File(file.path!).readAsBytesSync();
        }

        if (bytes != null) {
          pickedFiles.add(
            PendingFile(
              name: file.name,
              bytes: bytes,
              sizeBytes: file.size,
              status: UploadStatus.queued,
            ),
          );
        }
      }

      if (pickedFiles.isNotEmpty) {
        widget.onFilesPicked(pickedFiles);
      }
    } catch (e) {
      debugPrint('[AgriDrone] Error picking files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = widget.compact ? 120.0 : 200.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _pickFiles,
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: _isHovered ? AppColors.green : AppColors.lineBright,
            borderRadius: 14.0,
            strokeWidth: _isHovered ? 2.0 : 1.5,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppColors.green.withAlpha((255 * 0.05).toInt())
                  : AppColors.glass,
              borderRadius: BorderRadius.circular(14.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.compact ? Icons.cloud_upload_outlined : Icons.drive_folder_upload,
                  color: _isHovered ? AppColors.green : AppColors.textDim,
                  size: widget.compact ? 28.0 : 42.0,
                ),
                const SizedBox(height: 10.0),
                Text(
                  widget.compact ? 'TAP TO BROWSE' : 'DRAG IMAGES HERE OR CLICK TO BROWSE',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: widget.compact ? 11.0 : 13.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (!widget.compact) ...[
                  const SizedBox(height: 6.0),
                  Text(
                    'PNG, JPG up to 10MB each',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textFaint,
                      fontSize: 10.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter to draw rounded dashed borders.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 6.0,
    this.dash = 6.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashedPath = Path();
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashedPath.addPath(
          pathMetric.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
      distance = 0.0; // Reset for next metric segment if any
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.dash != dash ||
      oldDelegate.borderRadius != borderRadius;
}
