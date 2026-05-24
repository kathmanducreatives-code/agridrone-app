import 'package:flutter/material.dart';
import '../models/detection.dart';

/// A painter that draws YOLOv8 bounding boxes onto a canvas, scaled dynamically.
class BboxPainter extends CustomPainter {
  final List<Detection> detections;
  final bool showLabels;

  BboxPainter({required this.detections, this.showLabels = true});

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinates are based on 1600x1200 UXGA source images
    final double scaleX = size.width / 1600.0;
    final double scaleY = size.height / 1200.0;

    for (final detection in detections) {
      final x1 = detection.bboxX1;
      final y1 = detection.bboxY1;
      final x2 = detection.bboxX2;
      final y2 = detection.bboxY2;

      if (x1 == null || y1 == null || x2 == null || y2 == null) {
        continue;
      }

      final double scaledX1 = x1 * scaleX;
      final double scaledY1 = y1 * scaleY;
      final double scaledX2 = x2 * scaleX;
      final double scaledY2 = y2 * scaleY;

      final rect = Rect.fromLTRB(scaledX1, scaledY1, scaledX2, scaledY2);
      
      final paint = Paint()
        ..color = detection.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // Draw bounding box
      canvas.drawRect(rect, paint);

      if (showLabels) {
        // Prepare label text
        final textSpan = TextSpan(
          text: '${detection.displayLabel.toUpperCase()} ${detection.confidencePercent}',
          style: TextStyle(
            color: Colors.black,
            fontSize: size.width > 250 ? 10.0 : 8.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrains Mono',
          ),
        );
        
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        final labelHeight = textPainter.height + 4.0;
        final labelWidth = textPainter.width + 8.0;

        // Position label above the box if it fits, else inside at the top
        final double labelY = (scaledY1 - labelHeight >= 0) ? (scaledY1 - labelHeight) : scaledY1;

        final labelRect = Rect.fromLTWH(
          scaledX1,
          labelY,
          labelWidth,
          labelHeight,
        );

        final labelPaint = Paint()..color = detection.color;
        canvas.drawRect(labelRect, labelPaint);

        textPainter.paint(
          canvas,
          Offset(scaledX1 + 4.0, labelY + 2.0),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BboxPainter oldDelegate) {
    return oldDelegate.detections != detections || oldDelegate.showLabels != showLabels;
  }
}

/// Overlay widget that wraps an image and places a CustomPaint bounding box layer on top.
class BboxOverlay extends StatelessWidget {
  final Widget child;
  final List<Detection> detections;
  final bool showLabels;

  const BboxOverlay({
    super.key,
    required this.child,
    required this.detections,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: CustomPaint(
            painter: BboxPainter(detections: detections, showLabels: showLabels),
          ),
        ),
      ],
    );
  }
}
