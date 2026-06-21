import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/gallery_tile.dart';
import '../widgets/bbox_overlay.dart';
import '../widgets/detection_card.dart';
import '../widgets/lab_upload_button_modal.dart';
import '../widgets/ai_assistant_panel.dart';
import '../models/ai_assistant.dart';
import 'diagnosis_detail_screen.dart';
import '../models/flight_capture.dart';
import '../models/detection.dart';
import '../providers/flight_providers.dart';
import '../providers/lab_providers.dart';
import '../providers/analysis_providers.dart';

/// Crop image library for review, image quality decisions, and crop checks.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  void _toggleSelection(WidgetRef ref, int captureId) {
    ref.read(selectedCapturesProvider.notifier).toggle(captureId);
  }

  void _openDetailsModal(BuildContext context, WidgetRef ref,
      FlightCapture capture, List<Detection> detections) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((255 * 0.85).toInt()),
      builder: (_) => LabDetailsModal(
        capture: capture,
        detections: detections,
      ),
    );
  }

  Future<void> _rejectSelected(BuildContext context, WidgetRef ref,
      List<FlightCapture> selectedList) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'MARK ${selectedList.length} IMAGES AS NEEDING RETAKE?',
          style: GoogleFonts.spaceGrotesk(
              color: AppColors.rejected, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'These images will be marked as needing a better image and hidden from the main gallery by default.',
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
                backgroundColor: AppColors.rejected,
                foregroundColor: Colors.white),
            child: Text('MARK NEEDS RETAKE',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final supabase = ref.read(supabaseServiceProvider);
      for (final cap in selectedList) {
        try {
          await supabase.markReviewed(cap.id, rejected: true);
        } catch (e) {
          debugPrint('[AgriDrone] Error rejecting capture ${cap.id}: $e');
        }
      }
      if (!context.mounted) return;
      ref.read(selectedCapturesProvider.notifier).clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Marked ${selectedList.length} images as needing a better image.'),
          backgroundColor: AppColors.greenDeep,
        ),
      );
    }
  }

  void _analyzeSelected(
      BuildContext context, WidgetRef ref, List<FlightCapture> selectedList) {
    // Reset progressive status tracker
    ref.read(analysisProgressProvider.notifier).reset();

    // Open Sequential Progress Modal overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AnalysisProgressModal(selectedList: selectedList),
    ).then((_) {
      // Clear selections on modal close
      ref.read(selectedCapturesProvider.notifier).clear();
    });

    // Fire the progressive inference execution loop
    ref.read(analysisProgressProvider.notifier).runAnalysis(selectedList);
  }

  void _openUploadModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((255 * 0.85).toInt()),
      builder: (_) => const LabUploadButtonModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturesAsync = ref.watch(labCapturesProvider);
    final flightsAsync = ref.watch(allFlightsProvider);
    final detectionsAsync = ref.watch(allDetectionsProvider);
    final filter = ref.watch(labFilterProvider);
    final filterNotifier = ref.read(labFilterProvider.notifier);
    final selectedIds = ref.watch(selectedCapturesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Crop image filters and actions.
            GlassCard(
              bright: false,
              borderRadius: 0.0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upper row (Header & resets)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CROP IMAGES',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openUploadModal(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.green,
                              side:
                                  const BorderSide(color: AppColors.lineBright),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 8.0),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6.0)),
                            ),
                            icon: const Icon(Icons.upload_file, size: 14.0),
                            label: Text('UPLOAD IMAGE',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8.0),
                          TextButton(
                            onPressed: () {
                              filterNotifier.reset();
                              ref
                                  .read(selectedCapturesProvider.notifier)
                                  .clear();
                            },
                            child: Text(
                              'RESET FILTERS',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.green,
                                fontSize: 11.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Middle Row (Flight IDs & View Modes Dropdowns)
                  Row(
                    children: [
                      // Flights selector
                      Expanded(
                        child: flightsAsync.maybeWhen(
                          data: (flightsList) {
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  value: filter.flightId,
                                  dropdownColor: AppColors.surface,
                                  hint: Text(
                                    'All Flights',
                                    style: GoogleFonts.spaceGrotesk(
                                        color: AppColors.text, fontSize: 13.0),
                                  ),
                                  items: [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        'All Flights',
                                        style: GoogleFonts.spaceGrotesk(
                                            color: AppColors.text,
                                            fontSize: 13.0),
                                      ),
                                    ),
                                    ...flightsList
                                        .map((f) => DropdownMenuItem<int?>(
                                              value: f.flightId,
                                              child: Text(
                                                'Flight FLT_${f.flightId.toString().padLeft(4, '0')}',
                                                style:
                                                    GoogleFonts.jetBrainsMono(
                                                        color: AppColors.text,
                                                        fontSize: 13.0),
                                              ),
                                            )),
                                  ],
                                  onChanged: (id) =>
                                      filterNotifier.setFlightId(id),
                                ),
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 12.0),

                      // View Mode selector
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: filter.viewMode,
                              dropdownColor: AppColors.surface,
                              items: [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Needs Review',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: AppColors.text,
                                          fontSize: 13.0)),
                                ),
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Images',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: AppColors.text,
                                          fontSize: 13.0)),
                                ),
                                DropdownMenuItem(
                                  value: 'analyzed',
                                  child: Text('Checked Only',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: AppColors.text,
                                          fontSize: 13.0)),
                                ),
                                DropdownMenuItem(
                                  value: 'rejected',
                                  child: Text('Rejected Only',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: AppColors.text,
                                          fontSize: 13.0)),
                                ),
                              ],
                              onChanged: (mode) =>
                                  filterNotifier.setViewMode(mode ?? 'pending'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),

                  // Bottom Row (Show rejected switch, and selection action controls)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: filter.showRejected,
                            activeTrackColor:
                                AppColors.green.withAlpha((255 * 0.15).toInt()),
                            activeThumbColor: AppColors.green,
                            inactiveTrackColor: AppColors.surface,
                            inactiveThumbColor: AppColors.textFaint,
                            onChanged: (_) =>
                                filterNotifier.toggleShowRejected(),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'SHOW IMAGES THAT NEED RETAKE',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.textFaint,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Active review actions strip (visible when selectedIds count > 0)
            if (selectedIds.isNotEmpty) ...[
              capturesAsync.maybeWhen(
                data: (capturesList) {
                  final curSelectedList = capturesList
                      .where((c) => selectedIds.contains(c.id))
                      .toList();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                    color: AppColors.surface2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedIds.length} IMAGES SELECTED',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.selected,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.0,
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _rejectSelected(
                                  context, ref, curSelectedList),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.rejected,
                                side:
                                    const BorderSide(color: AppColors.rejected),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 8.0),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6.0)),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 14.0),
                              label: Text('NEEDS RETAKE',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10.0),
                            ElevatedButton.icon(
                              onPressed: () => _analyzeSelected(
                                  context, ref, curSelectedList),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0, vertical: 8.0),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6.0)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 14.0),
                              label: Text('CHECK ${selectedIds.length}',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],

            // 3. Grid Gallery Grid
            Expanded(
              child: capturesAsync.when(
                data: (captures) {
                  if (captures.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              color: AppColors.textFaint, size: 48.0),
                          const SizedBox(height: 16.0),
                          Text(
                            'No crop images match these filters.',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppColors.textDim, fontSize: 14.0),
                          ),
                          const SizedBox(height: 14.0),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DiagnosisDetailScreen.demo(),
                              ),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Use Sample Diagnosis'),
                          ),
                        ],
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 2;
                      if (constraints.maxWidth >= 1200) {
                        crossAxisCount = 4;
                      } else if (constraints.maxWidth >= 800) {
                        crossAxisCount = 3;
                      } else if (constraints.maxWidth >= 500) {
                        crossAxisCount = 2;
                      } else {
                        crossAxisCount = 1;
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16.0),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16.0,
                          mainAxisSpacing: 16.0,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: captures.length,
                        itemBuilder: (context, index) {
                          final cap = captures[index];
                          final detectionsList = detectionsAsync.value ?? [];
                          final capDetections = detectionsList
                              .where((d) => d.flightCaptureId == cap.id)
                              .toList();

                          return GalleryTile(
                            capture: cap,
                            isSelected: selectedIds.contains(cap.id),
                            detections: capDetections,
                            onTap: () => _toggleSelection(ref, cap.id),
                            onLongPress: () => _openDetailsModal(
                                context, ref, cap, capDetections),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.green)),
                error: (err, stack) => Center(
                  child: Text('Error: $err',
                      style: const TextStyle(color: AppColors.crit)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen detailed view long-press tile dialog.
class LabDetailsModal extends ConsumerStatefulWidget {
  final FlightCapture capture;
  final List<Detection> detections;

  const LabDetailsModal({
    super.key,
    required this.capture,
    required this.detections,
  });

  @override
  ConsumerState<LabDetailsModal> createState() => _LabDetailsModalState();
}

class _LabDetailsModalState extends ConsumerState<LabDetailsModal> {
  bool _curating = false;

  AiDetectionContext? get _aiContext {
    if (widget.detections.isEmpty) return null;
    final primary = [...widget.detections]
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
      captureId: widget.capture.id.toString(),
      detectionId: detection.id.toString(),
      flightId: widget.capture.flightId.toString(),
      diseaseName: detection.label,
      confidence: detection.confidence,
      severity: _severityFromConfidence(detection.confidence),
      cropType: 'rice',
      moisturePct: widget.capture.moisturePct,
      bbox: bbox,
    );
  }

  String _severityFromConfidence(double confidence) {
    if (confidence >= 0.80) return 'high';
    if (confidence >= 0.50) return 'moderate';
    return 'low';
  }

  Future<void> _updateCuration(bool rejected) async {
    setState(() => _curating = true);
    try {
      await ref
          .read(supabaseServiceProvider)
          .markReviewed(widget.capture.id, rejected: rejected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rejected
                ? 'Image marked as needing a better image.'
                : 'Image is ready for crop health checking.'),
            backgroundColor: AppColors.greenDeep,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Image update failed: $e'),
              backgroundColor: AppColors.crit),
        );
      }
    } finally {
      if (mounted) setState(() => _curating = false);
    }
  }

  Future<void> _forceAnalysis() async {
    setState(() => _curating = true);
    try {
      await ref
          .read(supabaseServiceProvider)
          .requestAnalysis(widget.capture.id);

      final res = await ref.read(huggingFaceServiceProvider).predict(
            imageUrl: widget.capture.imageUrl ?? '',
            flightCaptureId: widget.capture.id,
            flightId: widget.capture.flightId,
            imageIndex: widget.capture.imageIndex,
          );

      final rawDetections = res['detections'];
      final count = res['detections_count'] is int
          ? res['detections_count'] as int
          : rawDetections is List
              ? rawDetections.length
              : 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? 'Analysis completed: no disease detections found.'
                  : 'Re-analysis completed: $count detections recorded.',
            ),
            backgroundColor: count == 0 ? AppColors.greenDeep : AppColors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Analysis failed: $e'),
              backgroundColor: AppColors.crit),
        );
      }
    } finally {
      if (mounted) setState(() => _curating = false);
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.capture.imageUrl ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Public URL copied to clipboard'),
          backgroundColor: AppColors.greenDeep),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.capture.imageUrl ?? '';

    return Dialog.fullscreen(
      backgroundColor: AppColors.bg,
      child: Column(
        children: [
          // Modal Top Bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CAPTURE ENVELOPE: FLT_${widget.capture.flightId} (IDX #${widget.capture.imageIndex})',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Visual BBox Image Area
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: BboxOverlay(
                      detections: widget.detections,
                      showLabels: true,
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.green),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: AppColors.crit, size: 48.0),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                const VerticalDivider(color: AppColors.line, width: 1.0),

                // Metrics Sidebar Area
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
                            'FILE & TELEMETRY LOGS',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.textDim,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          _buildSidebarLabelValue(
                              'DEVICE IDENTIFIER', widget.capture.deviceId),
                          _buildSidebarLabelValue(
                              'CAPTURED TIMESTAMP',
                              widget.capture.uploadedAt != null
                                  ? widget.capture.uploadedAt!
                                      .toLocal()
                                      .toString()
                                      .substring(11, 19)
                                  : '—'),
                          _buildSidebarLabelValue(
                              'SOIL MOISTURE READING',
                              widget.capture.moisturePct != null
                                  ? '${widget.capture.moisturePct!.toStringAsFixed(1)}%'
                                  : 'N/A'),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(color: AppColors.line),
                          ),

                          Text(
                            'DISEASES LOGGED',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.textDim,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12.0),

                          SizedBox(
                            height: 150.0,
                            child: widget.detections.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No infections verified currently.',
                                      style: TextStyle(
                                          color: AppColors.textFaint,
                                          fontSize: 13.0),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: widget.detections.length,
                                    itemBuilder: (context, index) {
                                      final det = widget.detections[index];
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8.0),
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          color: det.color
                                              .withAlpha((255 * 0.05).toInt()),
                                          borderRadius:
                                              BorderRadius.circular(6.0),
                                          border: Border.all(
                                              color: det.color.withAlpha(
                                                  (255 * 0.25).toInt())),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                det.displayLabel,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.spaceGrotesk(
                                                  color: det.color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.0,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8.0),
                                            Text(
                                              det.confidencePercent,
                                              style: GoogleFonts.jetBrainsMono(
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

                          // Curation Operations Controls
                          _curating
                              ? const Center(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 12.0),
                                    child: CircularProgressIndicator(
                                        color: AppColors.green),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                _updateCuration(true),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.rejected,
                                              side: const BorderSide(
                                                  color: AppColors.rejected),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12.0),
                                            ),
                                            child: Text('NEEDS RETAKE',
                                                style: GoogleFonts.spaceGrotesk(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.0)),
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _updateCuration(false),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.green,
                                              foregroundColor: Colors.black,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12.0),
                                            ),
                                            child: Text('SELECT',
                                                style: GoogleFonts.spaceGrotesk(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.0)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10.0),
                                    ElevatedButton.icon(
                                      onPressed: _forceAnalysis,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.surface2,
                                        foregroundColor: AppColors.text,
                                        side: const BorderSide(
                                            color: AppColors.line),
                                        minimumSize:
                                            const Size.fromHeight(44.0),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8.0)),
                                      ),
                                      icon: const Icon(Icons.rocket_launch,
                                          size: 16.0),
                                      label: Text('CHECK AGAIN',
                                          style: GoogleFonts.spaceGrotesk(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.0)),
                                    ),
                                    const SizedBox(height: 8.0),
                                    OutlinedButton.icon(
                                      onPressed: _copyUrl,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.text,
                                        side: const BorderSide(
                                            color: AppColors.lineBright),
                                        minimumSize:
                                            const Size.fromHeight(44.0),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8.0)),
                                      ),
                                      icon: const Icon(Icons.copy_all_outlined,
                                          size: 16.0),
                                      label: Text('COPY IMAGE URL',
                                          style: GoogleFonts.spaceGrotesk(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.0)),
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

  Widget _buildSidebarLabelValue(String label, String value) {
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
                fontSize: 12.0,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Modal dialog overlay displaying progressive AI inference status.
class AnalysisProgressModal extends ConsumerWidget {
  final List<FlightCapture> selectedList;

  const AnalysisProgressModal({
    super.key,
    required this.selectedList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(analysisProgressProvider);

    final double completionRatio = progress.total == 0
        ? 0.0
        : (progress.completed + progress.failed) / progress.total;

    return PopScope(
      canPop: progress.isComplete, // Block popping until loop finishes
      child: Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(20.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
        child: Container(
          width: 550.0,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'AI ANALYSIS SEQUENTIAL QUEUE',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16.0),

              // Progress description
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progress.isComplete
                        ? 'ANALYSIS COMPLETED'
                        : 'Processing ${progress.completed + progress.failed + 1} of ${progress.total}...',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                    ),
                  ),
                  Text(
                    '${(completionRatio * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.jetBrainsMono(
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),

              // Smooth Linear Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: LinearProgressIndicator(
                  value: completionRatio,
                  minHeight: 8.0,
                  backgroundColor: AppColors.surface2,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.green),
                ),
              ),
              const SizedBox(height: 12.0),

              // Complete counts summary strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniSummaryText('COMPLETED',
                      progress.completed.toString(), AppColors.green),
                  _buildMiniSummaryText(
                      'FAILED', progress.failed.toString(), AppColors.crit),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: AppColors.line),
              ),

              // Scrollable list of parsed output tiles
              Flexible(
                child: SizedBox(
                  height: 220.0,
                  child: progress.results.isEmpty
                      ? const Center(
                          child: Text(
                            'Preparing prediction queue...',
                            style: TextStyle(color: AppColors.textFaint),
                          ),
                        )
                      : ListView.builder(
                          itemCount: progress.results.length,
                          itemBuilder: (context, index) {
                            final res = progress.results[index];
                            final FlightCapture cap = res['capture'];
                            final bool success = res['success'] ?? false;

                            if (!success) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppColors.crit),
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: Text(
                                          'Crop image FLT_${cap.flightId} #${cap.imageIndex} needs attention: ${res['error']}',
                                          style: GoogleFonts.spaceGrotesk(
                                              color: AppColors.crit,
                                              fontSize: 11.0),
                                          maxLines: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Prepare mock or actual joined detections to display
                            final List rawDets = res['detections'] ?? [];
                            final detections = rawDets
                                .map((d) => Detection.fromJson(
                                    {...d, 'image_url': cap.imageUrl}))
                                .toList();

                            if (detections.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          color: AppColors.green),
                                      const SizedBox(width: 12.0),
                                      Text(
                                        'Crop image FLT_${cap.flightId} #${cap.imageIndex}: no disease found',
                                        style: GoogleFonts.spaceGrotesk(
                                            color: AppColors.text,
                                            fontSize: 12.0),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: detections
                                    .map((d) => DetectionCard(detection: d))
                                    .toList(),
                              ),
                            );
                          },
                        ),
                ),
              ),

              // Final closing controls
              if (progress.isComplete) ...[
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0)),
                  ),
                  child: Text(
                    'CLOSE CABINET',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold, fontSize: 13.0),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSummaryText(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.spaceGrotesk(
              color: AppColors.textFaint,
              fontSize: 10.0,
              fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
              color: color, fontSize: 11.0, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
