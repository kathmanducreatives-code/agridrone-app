import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../providers/test_upload_providers.dart';
import '../providers/dashboard_providers.dart'; // contains currentTabProvider
import '../providers/flight_providers.dart'; // contains huggingFaceServiceProvider
import '../widgets/upload_dropzone.dart';

/// Compact curation modal triggered from the Lab screen.
/// Selects, uploads, predicts sequentially, and auto-navigates to Test AI history tab.
class LabUploadButtonModal extends ConsumerStatefulWidget {
  const LabUploadButtonModal({super.key});

  @override
  ConsumerState<LabUploadButtonModal> createState() =>
      _LabUploadButtonModalState();
}

class _LabUploadButtonModalState extends ConsumerState<LabUploadButtonModal> {
  List<PendingFile> _files = [];
  bool _isAnalyzing = false;

  void _onFilesPicked(List<PendingFile> files) {
    if (_isAnalyzing) return;
    setState(() {
      _files = [..._files, ...files];
    });
  }

  Future<void> _startSequentialAnalysis() async {
    if (_files.isEmpty || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    final service = ref.read(testUploadServiceProvider);
    final hfService = ref.read(huggingFaceServiceProvider);

    for (int i = 0; i < _files.length; i++) {
      final file = _files[i];
      if (file.status == UploadStatus.complete ||
          file.status == UploadStatus.failed) {
        continue;
      }

      try {
        setState(() {
          file.status = UploadStatus.uploading;
        });

        // 1. Upload file binary data
        final imageUrl = await service.uploadImageBytes(
          bytes: file.bytes,
          filename: file.name,
        );

        // Extract uuid from image URL or parse manually
        // URL format: .../test-uploads/<uuid>.<ext>
        final uri = Uri.parse(imageUrl);
        final filenamePart = uri.pathSegments.last;
        final uuid = filenamePart.split('.').first;

        setState(() {
          file.status = UploadStatus.analyzing;
        });

        // 2. Create DB entry
        final uploadId = await service.createTestUploadRow(
          uuid: uuid,
          filename: file.name,
          imageUrl: imageUrl,
          sizeBytes: file.sizeBytes,
        );
        file.testUploadId = uploadId;

        // 3. Mark ready for analysis
        await service.requestAnalysis(uploadId);

        // 4. Call HuggingFace FastAPI YOLO model predict
        await hfService.predictForTestUpload(
          imageUrl: imageUrl,
          testUploadId: uploadId,
        );

        // 5. Query results
        final detections = await service.getDetectionsForUpload(uploadId);

        if (mounted) {
          setState(() {
            file.detections = detections;
            file.status = UploadStatus.complete;
          });
        }
      } catch (e) {
        debugPrint('[AgriDrone] Analysis failed for file ${file.name}: $e');
        if (mounted) {
          setState(() {
            file.status = UploadStatus.failed;
            file.error = e.toString();
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
      });

      // Clear the modal file picker list
      ref.read(pendingFilesProvider.notifier).clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crop image batch processing complete.'),
          backgroundColor: AppColors.greenDeep,
        ),
      );

      // Auto-navigate back to Crop Images after the batch finishes.
      ref.read(currentTabProvider.notifier).set(3);

      // Close the modal
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _files.isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Container(
        width: 500.0,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CHECK CROP IMAGES',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textDim, size: 18.0),
                  onPressed: _isAnalyzing ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Dropzone
            UploadDropzone(
              onFilesPicked: _onFilesPicked,
              compact: true,
            ),
            const SizedBox(height: 16.0),

            // Picked Files Preview Box
            if (hasPending) ...[
              Text(
                'READY TO CHECK (${_files.length} Files)',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim,
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6.0),
              Container(
                constraints: const BoxConstraints(maxHeight: 180.0),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: AppColors.line),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final sizeMB =
                        (file.sizeBytes / (1024 * 1024)).toStringAsFixed(2);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: AppColors.line, width: 0.5)),
                      ),
                      child: Row(
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
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  '$sizeMB MB',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppColors.textFaint,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusIndicator(file),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16.0),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isAnalyzing ? null : () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textDim,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                ElevatedButton(
                  onPressed: (!hasPending || _isAnalyzing)
                      ? null
                      : _startSequentialAnalysis,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                  ),
                  child: _isAnalyzing
                      ? const SizedBox(
                          height: 14.0,
                          width: 14.0,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.0,
                          ),
                        )
                      : Text(
                          'CHECK & VIEW',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.0,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(PendingFile file) {
    switch (file.status) {
      case UploadStatus.queued:
        return const Icon(Icons.schedule_outlined,
            color: AppColors.textFaint, size: 16.0);
      case UploadStatus.uploading:
        return const SizedBox(
          width: 14.0,
          height: 14.0,
          child: CircularProgressIndicator(
              color: AppColors.green, strokeWidth: 1.5),
        );
      case UploadStatus.analyzing:
        return const SizedBox(
          width: 14.0,
          height: 14.0,
          child: CircularProgressIndicator(
              color: AppColors.info, strokeWidth: 1.5),
        );
      case UploadStatus.complete:
        final count = file.detections?.length ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.green, size: 16.0),
            const SizedBox(width: 4.0),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
              decoration: BoxDecoration(
                color: count > 0
                    ? AppColors.crit.withAlpha((255 * 0.15).toInt())
                    : AppColors.greenDeep.withAlpha((255 * 0.15).toInt()),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: count > 0 ? AppColors.crit : AppColors.green,
                  width: 0.5,
                ),
              ),
              child: Text(
                count > 0 ? 'DISEASE FOUND' : 'HEALTHY',
                style: GoogleFonts.jetBrainsMono(
                  color: count > 0 ? AppColors.crit : AppColors.green,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      case UploadStatus.failed:
        return Tooltip(
          message: file.error ?? 'Unknown error occurred.',
          child: const Icon(Icons.error, color: AppColors.crit, size: 16.0),
        );
    }
  }
}
