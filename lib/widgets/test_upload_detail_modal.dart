import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_colors.dart';
import '../widgets/ai_assistant_panel.dart';
import '../models/ai_assistant.dart';
import '../models/test_upload.dart';
import '../models/test_detection.dart';
import '../providers/test_upload_providers.dart';
import '../providers/flight_providers.dart'; // contains huggingFaceServiceProvider

/// Bbox painter specifically designed for [TestDetection] models.
class TestBboxPainter extends CustomPainter {
  final List<TestDetection> detections;
  final bool showLabels;

  TestBboxPainter({required this.detections, this.showLabels = true});

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
        final textSpan = TextSpan(
          text:
              '${detection.displayLabel.toUpperCase()} ${detection.confidencePercent}',
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

        final double labelY =
            (scaledY1 - labelHeight >= 0) ? (scaledY1 - labelHeight) : scaledY1;

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
  bool shouldRepaint(covariant TestBboxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.showLabels != showLabels;
  }
}

/// Bbox overlay specifically designed for [TestDetection] models.
class TestBboxOverlay extends StatelessWidget {
  final Widget child;
  final List<TestDetection> detections;
  final bool showLabels;

  const TestBboxOverlay({
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
            painter:
                TestBboxPainter(detections: detections, showLabels: showLabels),
          ),
        ),
      ],
    );
  }
}

/// Detailed Fullscreen Modal displaying test upload file stats and prediction bounding boxes.
class TestUploadDetailModal extends ConsumerStatefulWidget {
  final TestUpload upload;

  const TestUploadDetailModal({
    super.key,
    required this.upload,
  });

  @override
  ConsumerState<TestUploadDetailModal> createState() =>
      _TestUploadDetailModalState();
}

class _TestUploadDetailModalState extends ConsumerState<TestUploadDetailModal> {
  bool _isLoading = false;
  List<TestDetection> _detections = [];
  String? _errorMessage;

  AiDetectionContext? get _aiContext {
    if (_detections.isEmpty) return null;
    final primary = [..._detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final detection = primary.first;
    final bbox = detection.bboxX1 != null &&
            detection.bboxY1 != null &&
            detection.bboxX2 != null &&
            detection.bboxY2 != null
        ? [
            detection.bboxX1!,
            detection.bboxY1!,
            detection.bboxX2!,
            detection.bboxY2!
          ]
        : null;
    return AiDetectionContext(
      diseaseName: detection.label,
      confidence: detection.confidence,
      severity: _severityFromConfidence(detection.confidence),
      cropType: 'rice',
      bbox: bbox,
    );
  }

  String _severityFromConfidence(double confidence) {
    if (confidence >= 0.80) return 'high';
    if (confidence >= 0.50) return 'moderate';
    return 'low';
  }

  @override
  void initState() {
    super.initState();
    _fetchDetections();
  }

  Future<void> _fetchDetections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detections = await ref
          .read(testUploadServiceProvider)
          .getDetectionsForUpload(widget.upload.id);
      if (mounted) {
        setState(() {
          _detections = detections;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load detections: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forceReanalyze() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(testUploadServiceProvider);
      // Mark ready for analysis
      await service.requestAnalysis(widget.upload.id);

      // Trigger FastAPI prediction
      final res =
          await ref.read(huggingFaceServiceProvider).predictForTestUpload(
                imageUrl: widget.upload.imageUrl,
                testUploadId: widget.upload.id,
              );

      final rawDetections = res['detections'];
      final count = res['detections_count'] is int
          ? res['detections_count'] as int
          : rawDetections is List
              ? rawDetections.length
              : 0;

      // Reload detections
      final updatedDetections =
          await service.getDetectionsForUpload(widget.upload.id);

      if (mounted) {
        setState(() {
          _detections = updatedDetections;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? 'Analysis completed: no disease detections found.'
                  : 'Re-analysis completed: $count detections found.',
            ),
            backgroundColor: AppColors.greenDeep,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Re-analysis failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: AppColors.crit,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteUpload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'DELETE CROP CHECK?',
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.crit,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This action will permanently delete this crop image check and its saved results.',
          style: GoogleFonts.spaceGrotesk(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL',
                style: GoogleFonts.spaceGrotesk(color: AppColors.textDim)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crit,
              foregroundColor: Colors.white,
            ),
            child: Text('DELETE',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ref
            .read(testUploadServiceProvider)
            .deleteTestUpload(widget.upload.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crop image check deleted.'),
              backgroundColor: AppColors.greenDeep,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deletion failed: $e'),
              backgroundColor: AppColors.crit,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.upload.imageUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Public URL copied to clipboard'),
        backgroundColor: AppColors.greenDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeStr = widget.upload.imageSizeBytes != null
        ? '${(widget.upload.imageSizeBytes! / (1024 * 1024)).toStringAsFixed(2)} MB'
        : 'Unknown size';

    final timestampStr =
        widget.upload.uploadedAt.toLocal().toString().substring(0, 19);

    return Dialog.fullscreen(
      backgroundColor: AppColors.bg,
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'TEST FILE: ${widget.upload.sourceFilename ?? widget.upload.uploadUuid}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textDim),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.line, height: 1.0),

          // Main Responsive Grid
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bbox Image Visualizer Panel
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TestBboxOverlay(
                            detections: _detections,
                            showLabels: true,
                            child: CachedNetworkImage(
                              imageUrl: widget.upload.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.green),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: AppColors.crit, size: 48.0),
                              ),
                            ),
                          ),
                        ),
                        if (_isLoading)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.green),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(color: AppColors.line, width: 1.0),

                // Diagnostic/Metadata Sidebar
                Expanded(
                  flex: 1,
                  child: Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(20.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CROP CHECK DETAILS',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.textDim,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          _buildSidebarField(
                              'UUID IDENTIFIER', widget.upload.uploadUuid),
                          _buildSidebarField('FILE SIZE', sizeStr),
                          _buildSidebarField('CHECKED TIME', timestampStr),
                          _buildSidebarField(
                              'OPERATOR', widget.upload.uploadedBy),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: AppColors.line),
                          ),

                          Text(
                            'DETECTIONS REPORTED',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.textDim,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12.0),

                          SizedBox(
                            height: 180.0,
                            child: _errorMessage != null
                                ? Center(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.crit,
                                          fontSize: 12.0),
                                    ),
                                  )
                                : _detections.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No diseases detected.',
                                          style: TextStyle(
                                              color: AppColors.textFaint,
                                              fontSize: 13.0),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _detections.length,
                                        itemBuilder: (context, index) {
                                          final det = _detections[index];
                                          final inferenceStr = det
                                                      .inferenceTimeMs !=
                                                  null
                                              ? '${det.inferenceTimeMs!.toStringAsFixed(0)}ms'
                                              : 'N/A';
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 8.0),
                                            padding: const EdgeInsets.all(8.0),
                                            decoration: BoxDecoration(
                                              color: det.color.withAlpha(
                                                  (255 * 0.05).toInt()),
                                              borderRadius:
                                                  BorderRadius.circular(6.0),
                                              border: Border.all(
                                                  color: det.color.withAlpha(
                                                      (255 * 0.20).toInt())),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      det.displayLabel,
                                                      style: GoogleFonts
                                                          .spaceGrotesk(
                                                        color: det.color,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12.0,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2.0),
                                                    Text(
                                                      'Inference: $inferenceStr',
                                                      style: GoogleFonts
                                                          .spaceGrotesk(
                                                        color:
                                                            AppColors.textFaint,
                                                        fontSize: 10.0,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  det.confidencePercent,
                                                  style:
                                                      GoogleFonts.jetBrainsMono(
                                                    color: AppColors.text,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                          ),

                          const SizedBox(height: 12.0),
                          SizedBox(
                            height: 360.0,
                            child: SingleChildScrollView(
                              child: AiAssistantPanel(context: _aiContext),
                            ),
                          ),

                          const Divider(color: AppColors.line),
                          const SizedBox(height: 16.0),

                          // Action Buttons Bar
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _forceReanalyze,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size.fromHeight(42.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0)),
                                ),
                                icon: const Icon(Icons.psychology_outlined,
                                    size: 16.0),
                                label: Text(
                                  'CHECK AGAIN',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.0),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              OutlinedButton.icon(
                                onPressed: _copyUrl,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.text,
                                  side: const BorderSide(
                                      color: AppColors.lineBright),
                                  minimumSize: const Size.fromHeight(42.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0)),
                                ),
                                icon: const Icon(Icons.copy_all, size: 16.0),
                                label: Text(
                                  'COPY URL',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.0),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _deleteUpload,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.crit,
                                  side: const BorderSide(color: AppColors.crit),
                                  minimumSize: const Size.fromHeight(42.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0)),
                                ),
                                icon: const Icon(Icons.delete_forever,
                                    size: 16.0),
                                label: Text(
                                  'DELETE',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.textFaint,
                fontSize: 9.0,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2.0),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
                color: AppColors.text,
                fontSize: 11.5,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
