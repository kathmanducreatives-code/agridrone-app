import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_dot.dart';
import '../widgets/upload_dropzone.dart';
import '../widgets/test_upload_detail_modal.dart';
import '../models/test_upload.dart';
import '../models/test_detection.dart';
import '../providers/test_upload_providers.dart';
import '../providers/flight_providers.dart'; // contains huggingFaceServiceProvider
import '../providers/realtime_providers.dart'; // contains realtimeConnectionProvider
import '../services/realtime_service.dart'; // contains RealtimeConnectionState

/// Farmer-facing crop image check screen.
class TestAiScreen extends ConsumerStatefulWidget {
  const TestAiScreen({super.key});

  @override
  ConsumerState<TestAiScreen> createState() => _TestAiScreenState();
}

class _TestAiScreenState extends ConsumerState<TestAiScreen> {
  bool _isAnalyzing = false;

  void _onFilesPicked(WidgetRef ref, List<PendingFile> files) {
    if (_isAnalyzing) return;
    ref.read(pendingFilesProvider.notifier).add(files);
  }

  void _clearPending(WidgetRef ref) {
    if (_isAnalyzing) return;
    ref.read(pendingFilesProvider.notifier).clear();
  }

  void _updateFileState(
    WidgetRef ref,
    PendingFile file,
    UploadStatus status, {
    List<TestDetection>? detections,
    String? error,
  }) {
    ref.read(pendingFilesProvider.notifier).updateFile(
          file,
          status,
          detections: detections,
          error: error,
        );
  }

  Future<void> _runBatchAnalysis(WidgetRef ref) async {
    final files = ref.read(pendingFilesProvider);
    if (files.isEmpty || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    final service = ref.read(testUploadServiceProvider);
    final hfService = ref.read(huggingFaceServiceProvider);

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      if (file.status == UploadStatus.complete ||
          file.status == UploadStatus.failed) {
        continue;
      }

      try {
        _updateFileState(ref, file, UploadStatus.uploading);

        // 1. Upload bytes
        final imageUrl = await service.uploadImageBytes(
          bytes: file.bytes,
          filename: file.name,
        );

        // Extract uuid from image url
        final uri = Uri.parse(imageUrl);
        final filenamePart = uri.pathSegments.last;
        final uuid = filenamePart.split('.').first;

        _updateFileState(ref, file, UploadStatus.analyzing);

        // 2. Create database row via RPC
        final uploadId = await service.createTestUploadRow(
          uuid: uuid,
          filename: file.name,
          imageUrl: imageUrl,
          sizeBytes: file.sizeBytes,
        );
        file.testUploadId = uploadId;

        // 3. Mark ready for analysis via RPC
        await service.requestAnalysis(uploadId);

        // 4. FastAPI /predict call
        await hfService.predictForTestUpload(
          imageUrl: imageUrl,
          testUploadId: uploadId,
        );

        // 5. Query detections
        final detections = await service.getDetectionsForUpload(uploadId);

        _updateFileState(ref, file, UploadStatus.complete,
            detections: detections);
      } catch (e) {
        debugPrint('[AgriDrone] Step failure for ${file.name}: $e');
        _updateFileState(ref, file, UploadStatus.failed, error: e.toString());
      }
    }

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
      });

      // Force refresh history feed
      ref.invalidate(allTestUploadsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All files in batch processed.'),
          backgroundColor: AppColors.greenDeep,
        ),
      );
    }
  }

  void _openDetailsModal(TestUpload upload) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((255 * 0.85).toInt()),
      builder: (_) => TestUploadDetailModal(upload: upload),
    ).then((_) {
      if (mounted) {
        // Invalidate provider to fetch fresh logs when modal exits
        ref.invalidate(allTestUploadsProvider);
      }
    });
  }

  Future<void> _confirmDelete(TestUpload upload) async {
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
                backgroundColor: AppColors.crit, foregroundColor: Colors.white),
            child: Text('CONFIRM DELETE',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(testUploadServiceProvider).deleteTestUpload(upload.id);
        if (mounted) {
          ref.invalidate(allTestUploadsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crop image check deleted successfully.'),
              backgroundColor: AppColors.greenDeep,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete crop image check: $e'),
              backgroundColor: AppColors.crit,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connStateAsync = ref.watch(realtimeConnectionProvider);
    final pendingFiles = ref.watch(pendingFilesProvider);
    final historyAsync = ref.watch(allTestUploadsProvider);

    Color connectionColor = AppColors.crit;
    connStateAsync.whenData((state) {
      if (state == RealtimeConnectionState.connected) {
        connectionColor = AppColors.green;
      } else if (state == RealtimeConnectionState.connecting) {
        connectionColor = AppColors.warn;
      }
    });

    final hasPending = pendingFiles.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Navigation Header Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHECK CROP HEALTH',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Upload a crop image for an AI health check',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.textFaint,
                          fontSize: 11.0,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      StatusDot(color: connectionColor, size: 8.0),
                      const SizedBox(width: 8.0),
                      Text(
                        connStateAsync.maybeWhen(
                          data: _connectionLabel,
                          orElse: () => 'GETTING READY',
                        ),
                        style: GoogleFonts.jetBrainsMono(
                          color: connectionColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.line, height: 1.0),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      'Upload a clear leaf or crop image. AgriDrone AI checks crop health, explains the issue, and gives clear next steps.',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.textDim,
                        fontSize: 13.0,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20.0),

                    // Dropzone picker
                    UploadDropzone(
                      onFilesPicked: (files) => _onFilesPicked(ref, files),
                      compact: false,
                    ),
                    const SizedBox(height: 24.0),

                    // 2. Sequential Preview Progress Section
                    if (hasPending) ...[
                      _buildPreviewProgressHeader(ref, pendingFiles),
                      const SizedBox(height: 12.0),
                      _buildPreviewGrid(pendingFiles),
                      const SizedBox(height: 28.0),
                    ],

                    // 3. History Feed Dashboard
                    Row(
                      children: [
                        Expanded(
                            child: _buildDividerLabel('PREVIOUS CROP CHECKS')),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    _buildHistorySection(historyAsync),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.textDim,
            fontSize: 11.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 12.0),
        const Expanded(
          child: Divider(color: AppColors.line, height: 1.0),
        ),
      ],
    );
  }

  String _connectionLabel(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return 'READY';
      case RealtimeConnectionState.connecting:
        return 'GETTING READY';
      case RealtimeConnectionState.disconnected:
        return 'OFFLINE MODE';
      case RealtimeConnectionState.error:
        return 'NEEDS CONNECTION';
    }
  }

  Widget _buildPreviewProgressHeader(
      WidgetRef ref, List<PendingFile> pendingFiles) {
    final completedCount =
        pendingFiles.where((f) => f.status == UploadStatus.complete).length;
    final failedCount =
        pendingFiles.where((f) => f.status == UploadStatus.failed).length;
    final total = pendingFiles.length;

    final ratio = total == 0 ? 0.0 : (completedCount + failedCount) / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CROP CHECK PROGRESS ($total IMAGES)',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _isAnalyzing ? null : () => _clearPending(ref),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.rejected),
                  icon: const Icon(Icons.close_rounded, size: 14.0),
                  label: Text('CLEAR ALL',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10.0, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _runBatchAnalysis(ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.0)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 14.0),
                  label: Text('CHECK ALL',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10.0, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        if (_isAnalyzing) ...[
          const SizedBox(height: 8.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.surface,
              color: AppColors.green,
              minHeight: 5.0,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewGrid(List<PendingFile> pendingFiles) {
    return SizedBox(
      height: 120.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pendingFiles.length,
        itemBuilder: (context, index) {
          final file = pendingFiles[index];
          final sizeMB = (file.sizeBytes / (1024 * 1024)).toStringAsFixed(1);

          return Container(
            width: 140.0,
            margin: const EdgeInsets.only(right: 12.0),
            child: GlassCard(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            color: AppColors.text,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          '$sizeMB MB',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.textFaint,
                            fontSize: 9.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPreviewStatusBadge(file),
                      _buildStatusIcon(file),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewStatusBadge(PendingFile file) {
    switch (file.status) {
      case UploadStatus.queued:
        return Text('NEW',
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.textFaint,
                fontSize: 8.5,
                fontWeight: FontWeight.bold));
      case UploadStatus.uploading:
        return Text('UPLOADING',
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.green,
                fontSize: 8.5,
                fontWeight: FontWeight.bold));
      case UploadStatus.analyzing:
        return Text('CHECKING',
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.info,
                fontSize: 8.5,
                fontWeight: FontWeight.bold));
      case UploadStatus.complete:
        final count = file.detections?.length ?? 0;
        return Text(count > 0 ? 'DISEASE FOUND' : 'HEALTHY',
            style: GoogleFonts.spaceGrotesk(
                color: count > 0 ? AppColors.crit : AppColors.greenSoft,
                fontSize: 8.5,
                fontWeight: FontWeight.bold));
      case UploadStatus.failed:
        return Text('NEEDS ATTENTION',
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.crit,
                fontSize: 8.5,
                fontWeight: FontWeight.bold));
    }
  }

  Widget _buildStatusIcon(PendingFile file) {
    switch (file.status) {
      case UploadStatus.queued:
        return const Icon(Icons.schedule,
            color: AppColors.textFaint, size: 14.0);
      case UploadStatus.uploading:
        return const SizedBox(
            width: 12.0,
            height: 12.0,
            child: CircularProgressIndicator(
                color: AppColors.green, strokeWidth: 1.5));
      case UploadStatus.analyzing:
        return const SizedBox(
            width: 12.0,
            height: 12.0,
            child: CircularProgressIndicator(
                color: AppColors.info, strokeWidth: 1.5));
      case UploadStatus.complete:
        return const Icon(Icons.check_circle_rounded,
            color: AppColors.green, size: 14.0);
      case UploadStatus.failed:
        return Tooltip(
          message: file.error ?? 'Step error reported.',
          child: const Icon(Icons.error_outline_rounded,
              color: AppColors.crit, size: 14.0),
        );
    }
  }

  Widget _buildHistorySection(AsyncValue<List<TestUpload>> historyAsync) {
    return historyAsync.when(
      data: (uploads) {
        if (uploads.isEmpty) {
          return Container(
            height: 180.0,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.science_outlined,
                    color: AppColors.textFaint, size: 40.0),
                const SizedBox(height: 12.0),
                Text(
                  'No crop images checked yet. Upload a crop image to get your first AI recommendation.',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textDim, fontSize: 13.0),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int columns = 2;
            if (constraints.maxWidth >= 1200) {
              columns = 4;
            } else if (constraints.maxWidth >= 800) {
              columns = 3;
            } else if (constraints.maxWidth >= 500) {
              columns = 2;
            } else {
              columns = 1;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.82,
              ),
              itemCount: uploads.length,
              itemBuilder: (context, index) {
                final upload = uploads[index];
                return _buildHistoryTile(upload);
              },
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: CircularProgressIndicator(color: AppColors.green),
        ),
      ),
      error: (e, s) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child:
              Text('Error: $e', style: const TextStyle(color: AppColors.crit)),
        ),
      ),
    );
  }

  Widget _buildHistoryTile(TestUpload upload) {
    final count = upload.detectionCount ?? 0;
    final maxConfidence = upload.maxConfidence ?? 0.0;
    final timeStr = DateFormat('MMM dd, hh:mm a').format(upload.uploadedAt);
    final sizeStr = upload.imageSizeBytes != null
        ? '${(upload.imageSizeBytes! / (1024 * 1024)).toStringAsFixed(1)}MB'
        : '—';

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 12.0,
      onTap: () => _openDetailsModal(upload),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image preview container
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12.0)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: upload.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.green, strokeWidth: 2.0),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child:
                          Icon(Icons.broken_image, color: AppColors.textFaint),
                    ),
                  ),

                  // Filename Overlay Banner
                  Positioned(
                    bottom: 0.0,
                    left: 0.0,
                    right: 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      color: Colors.black.withAlpha((255 * 0.70).toInt()),
                      child: Text(
                        upload.sourceFilename ?? upload.uploadUuid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.text,
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Delete Overlay Button
                  Positioned(
                    top: 6.0,
                    right: 6.0,
                    child: CircleAvatar(
                      backgroundColor:
                          Colors.black.withAlpha((255 * 0.60).toInt()),
                      radius: 14.0,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.crit, size: 12.0),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDelete(upload),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Detail specs section
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upload Timestamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeStr,
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.textFaint,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      sizeStr,
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.textFaint,
                        fontSize: 9.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),

                // Detection status chips
                Row(
                  children: [
                    Expanded(
                      child: upload.aiProcessed
                          ? count > 0
                              ? Wrap(
                                  spacing: 4.0,
                                  runSpacing: 4.0,
                                  children: [
                                    _buildLabelChip(
                                      upload.labelsFound ?? 'Disease',
                                      AppColors.crit,
                                    ),
                                    _buildLabelChip(
                                      '${(maxConfidence * 100).toStringAsFixed(0)}% MAX',
                                      AppColors.warn,
                                    ),
                                  ],
                                )
                              : _buildLabelChip('CLEAN', AppColors.greenSoft)
                          : _buildLabelChip('AWAITING AI', AppColors.textFaint),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.12).toInt()),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
            color: color.withAlpha((255 * 0.35).toInt()), width: 0.5),
      ),
      child: Text(
        text.toUpperCase().replaceAll('_', ' '),
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
