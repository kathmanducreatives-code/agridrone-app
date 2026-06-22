import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_assistant.dart';
import '../models/campaign_view.dart';
import '../models/detection.dart';
import '../models/flight_capture.dart';
import '../providers/campaign_providers.dart';
import '../providers/flight_providers.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../providers/map_providers.dart';
import '../providers/report_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_ui.dart';
import '../widgets/asset_illustrations.dart';
import '../widgets/gallery_tile.dart';
import 'diagnosis_detail_screen.dart';
import 'report_view_screen.dart';

/// Inline detail view for a Crop Campaign (drone-flight or manual).
///
/// Rendered inside the Campaigns tab (not a pushed route) so the global AI
/// Advisor overlay stays mounted and can be scoped to this campaign. All data
/// comes from real `flight_captures` / `detections` / `campaign_images`.
class CampaignDetailView extends ConsumerStatefulWidget {
  final CampaignView campaign;

  const CampaignDetailView({super.key, required this.campaign});

  @override
  ConsumerState<CampaignDetailView> createState() => _CampaignDetailViewState();
}

class _CampaignDetailViewState extends ConsumerState<CampaignDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(globalAiAdvisorProvider.notifier).setCampaignContext(
            campaign: widget.campaign.toAdvisorCampaign(),
            flight: widget.campaign.toAdvisorFlight(),
            extras: widget.campaign.fullAiExtras,
          );
    });
  }

  void _back() {
    ref.read(globalAiAdvisorProvider.notifier).clearCampaignContext();
    ref.read(selectedFlightCampaignProvider.notifier).clear();
  }

  void _refresh() {
    final c = widget.campaign;
    if (c.isDroneFlight && c.flightId != null) {
      ref.invalidate(flightCapturesProvider(c.flightId!));
      ref.invalidate(detectionsForFlightProvider(c.flightId!));
      ref.invalidate(allFlightsProvider);
    } else if (c.manualId != null) {
      ref.invalidate(campaignImagesProvider(c.manualId!));
      ref.invalidate(manualCampaignContentsProvider(c.manualId!));
      ref.invalidate(manualCampaignsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
    final isManual = !campaign.isDroneFlight;

    // Resolve captures + detections from the right source.
    AsyncValue<List<FlightCapture>> capturesAsync;
    List<Detection> detections;
    Map<int, String> linkIdByCapture = const {};
    // Device-uploaded images (campaign_images rows with no flight capture).
    List<Map<String, dynamic>> uploadedRows = const [];

    if (isManual) {
      final contents =
          ref.watch(manualCampaignContentsProvider(campaign.manualId!));
      capturesAsync = contents.whenData((c) => c.captures);
      detections = contents.asData?.value.detections ?? const [];
      final links = ref.watch(campaignImagesProvider(campaign.manualId!));
      final linkRows = links.asData?.value ?? const [];
      linkIdByCapture = {
        for (final l in linkRows)
          if (l['capture_id'] != null)
            (l['capture_id'] as num).toInt(): l['id'] as String,
      };
      uploadedRows = [
        for (final l in linkRows)
          if (l['capture_id'] == null && l['image_url'] != null) l,
      ];
    } else {
      final fid = campaign.flightId!;
      capturesAsync = ref.watch(flightCapturesProvider(fid));
      detections =
          ref.watch(detectionsForFlightProvider(fid)).asData?.value ?? const [];
    }

    final geotagged = ref.watch(geotaggedFlightIdsProvider);
    final gpsAvailable = campaign.isDroneFlight &&
        (geotagged.asData?.value.contains(campaign.flightId ?? -1) ?? false);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back to campaigns',
                    color: AppColors.greenDeep,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: PageHeader(
                      title: campaign.name,
                      subtitle: isManual
                          ? 'Your crop campaign. Add real crop images, run analysis and prepare a report — all from real data.'
                          : 'Crop campaign from a drone flight. Images, analysis and reports below come from real flight data.',
                    ),
                  ),
                  if (isManual) ...[
                    OutlinedButton.icon(
                      onPressed: () => _showAddImages(context),
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('Add Images'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(globalAiAdvisorProvider.notifier).open(),
                    icon: const Icon(Icons.eco_rounded),
                    label: const Text('Ask AI Advisor'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SummaryCard(
                campaign: campaign,
                gpsAvailable: gpsAvailable,
                gpsKnown: campaign.isDroneFlight ? geotagged.hasValue : true,
                isManual: isManual,
              ),
              if (campaign.env != null) ...[
                const SizedBox(height: 14),
                _EnvContextCards(env: campaign.env!),
              ],
              const SizedBox(height: 18),
              _AnalyzeImagesBar(
                captures: capturesAsync.asData?.value ?? const [],
                uploadedRows: uploadedRows,
                onChanged: _refresh,
              ),
              const SizedBox(height: 18),
              _ReportSection(campaign: campaign, detections: detections),
              const SizedBox(height: 18),
              Text(
                isManual ? 'Crop images in this campaign' : 'Crop images in this flight',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              capturesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const EmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Crop images need connection',
                  message:
                      'Crop images could not be loaded. Check your connection and try again.',
                ),
                data: (captures) {
                  if (captures.isEmpty && uploadedRows.isEmpty) {
                    return EmptyStateCard(
                      icon: Icons.image_not_supported_outlined,
                      title: isManual
                          ? 'No crop images in this campaign yet'
                          : 'No crop images in this flight yet',
                      message: isManual
                          ? 'Add crop images from your drone flights or upload photos from your device to start checking this campaign.'
                          : 'Images will appear here after the drone uploads them for this flight.',
                      actionLabel: isManual ? 'Add Images' : null,
                      onAction:
                          isManual ? () => _showAddImages(context) : null,
                      illustrationPath: AppAssets.emptyCropImages,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (captures.isNotEmpty)
                        _ImageGrid(
                          captures: captures,
                          detections: detections,
                          campaign: campaign,
                          onChanged: _refresh,
                          onRemove: isManual
                              ? (capture) => _removeImage(
                                  context, capture, linkIdByCapture)
                              : null,
                        ),
                      if (isManual && uploadedRows.isNotEmpty) ...[
                        if (captures.isNotEmpty) const SizedBox(height: 20),
                        Text(
                          'Uploaded photos',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _UploadedImagesGrid(
                          rows: uploadedRows,
                          persistedAnalysis: campaign.imageAnalysis,
                          onRemoved: _refresh,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeImage(
    BuildContext context,
    FlightCapture capture,
    Map<int, String> linkIdByCapture,
  ) async {
    final linkId = linkIdByCapture[capture.id];
    if (linkId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Remove image from campaign?',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900)),
        content: const Text(
            'This only removes the image from this campaign. The original crop image is kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(supabaseServiceProvider).removeCampaignImage(linkId);
      _refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not remove the image. Please try again.')));
      }
    }
  }

  void _showAddImages(BuildContext context) {
    final campaign = widget.campaign;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddImagesSheet(
        campaign: campaign,
        onAssigned: _refresh,
      ),
    );
  }
}

class _AddImagesSheet extends ConsumerStatefulWidget {
  final CampaignView campaign;
  final VoidCallback onAssigned;

  const _AddImagesSheet({required this.campaign, required this.onAssigned});

  @override
  ConsumerState<_AddImagesSheet> createState() => _AddImagesSheetState();
}

class _AddImagesSheetState extends ConsumerState<_AddImagesSheet> {
  final _busy = <int>{};
  int _mode = 0; // 0 = drone flights, 1 = from device
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add crop images',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                _mode == 0
                    ? 'Pick real crop images from your drone flights to add to this campaign.'
                    : 'Upload crop photos from your device to add to this campaign.',
                style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              _ModeToggle(
                mode: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _mode == 0
                    ? _buildDroneFlightPicker(scrollController)
                    : _buildDeviceUpload(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDroneFlightPicker(ScrollController scrollController) {
    final capturesAsync = ref.watch(allFlightCapturesProvider);
    final assigned = ref
            .watch(campaignImagesProvider(widget.campaign.manualId!))
            .asData
            ?.value ??
        const [];
    final assignedIds = <int>{
      for (final l in assigned)
        if (l['capture_id'] != null) (l['capture_id'] as num).toInt(),
    };

    return capturesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          const Center(child: Text('Crop images could not be loaded.')),
      data: (captures) {
        final available =
            captures.where((c) => !assignedIds.contains(c.id)).toList();
        if (available.isEmpty) {
          return const Center(
              child: Text('No more drone crop images available to add.'));
        }
        return GridView.builder(
          controller: scrollController,
          itemCount: available.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, i) {
            final cap = available[i];
            final busy = _busy.contains(cap.id);
            return Stack(
              children: [
                GalleryTile(
                  capture: cap,
                  isSelected: false,
                  detections: const [],
                  onTap: busy ? null : () => _assign(cap),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.green,
                          child:
                              Icon(Icons.add, size: 16, color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceUpload() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _uploading
                  ? Icons.cloud_upload_rounded
                  : Icons.add_photo_alternate_rounded,
              color: AppColors.greenDeep,
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _uploading ? 'Uploading photos…' : 'Add photos from your device',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Choose clear crop or leaf photos (PNG or JPG). They are added to this campaign and can be analyzed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_rounded),
            label: Text(_uploading ? 'Uploading…' : 'Choose Photos'),
          ),
        ],
      ),
    );
  }

  Future<void> _assign(FlightCapture capture) async {
    setState(() => _busy.add(capture.id));
    try {
      await ref.read(supabaseServiceProvider).assignCaptureToCampaign(
            campaignId: widget.campaign.manualId!,
            capture: capture,
          );
      ref.invalidate(campaignImagesProvider(widget.campaign.manualId!));
      widget.onAssigned();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not add the image. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(capture.id));
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    var added = 0;
    var failed = 0;
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) {
        failed++;
        continue;
      }
      try {
        await ref.read(supabaseServiceProvider).addDeviceImageToCampaign(
              campaignId: widget.campaign.manualId!,
              bytes: bytes,
              filename: f.name,
            );
        added++;
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(campaignImagesProvider(widget.campaign.manualId!));
    widget.onAssigned();
    if (mounted) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: failed == 0 ? AppColors.greenDeep : AppColors.warn,
        content: Text(failed == 0
            ? '$added photo(s) added from your device.'
            : '$added added, $failed could not be uploaded.'),
      ));
    }
  }
}

class _ModeToggle extends StatelessWidget {
  final int mode;
  final ValueChanged<int> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _seg('Drone Flights', Icons.flight_takeoff_rounded, 0),
          _seg('From Device', Icons.add_photo_alternate_rounded, 1),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, int value) {
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textDim),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campaign-level "Analyze Images" bar — runs Image Analysis (the crop-disease
/// model) on every image in the campaign and reports detected / no-disease
/// results.
class _AnalyzeImagesBar extends ConsumerStatefulWidget {
  final List<FlightCapture> captures;
  final List<Map<String, dynamic>> uploadedRows;
  final VoidCallback onChanged;

  const _AnalyzeImagesBar({
    required this.captures,
    required this.uploadedRows,
    required this.onChanged,
  });

  @override
  ConsumerState<_AnalyzeImagesBar> createState() => _AnalyzeImagesBarState();
}

class _AnalyzeImagesBarState extends ConsumerState<_AnalyzeImagesBar> {
  static const _healthy = {
    'clean_canopy',
    'healthy',
    'clean',
    'clear',
    'no_disease',
    'none',
  };

  bool _running = false;
  int _done = 0;
  int _total = 0;

  int get _imageCount => widget.captures.length + widget.uploadedRows.length;

  bool _isDisease(String label) =>
      !_healthy.contains(label.toLowerCase().trim().replaceAll(' ', '_'));

  /// Pretty disease labels found in a predict result (excludes healthy labels).
  List<String> _diseaseLabels(Map<String, dynamic> res) {
    final dets = (res['detections'] as List?) ?? const [];
    final out = <String>[];
    for (final d in dets) {
      if (d is! Map) continue;
      final label = (d['label'] ?? d['name'] ?? '').toString();
      if (label.isEmpty || !_isDisease(label)) continue;
      final pretty = label.replaceAll('_', ' ');
      if (!out.contains(pretty)) out.add(pretty);
    }
    return out;
  }

  Future<void> _analyzeAll() async {
    if (_imageCount == 0) {
      _toast('No crop images to analyze yet.', AppColors.warn);
      return;
    }
    final hf = ref.read(huggingFaceServiceProvider);
    final supa = ref.read(supabaseServiceProvider);
    final agg = <String, int>{};
    var analyzed = 0;
    var failed = 0;
    var withDisease = 0;

    setState(() {
      _running = true;
      _done = 0;
      _total = _imageCount;
    });

    void tally(List<String> diseases) {
      analyzed++;
      if (diseases.isNotEmpty) withDisease++;
      for (final d in diseases) {
        agg[d] = (agg[d] ?? 0) + 1;
      }
    }

    for (final cap in widget.captures) {
      final url = cap.imageUrl ?? '';
      if (url.isEmpty) {
        failed++;
      } else {
        try {
          try {
            await supa.requestAnalysis(cap.id);
          } catch (_) {/* best-effort persistence trigger */}
          final res = await hf.predict(
            imageUrl: url,
            flightCaptureId: cap.id,
            flightId: cap.flightId,
            imageIndex: cap.imageIndex,
          );
          tally(_diseaseLabels(res));
        } catch (_) {
          failed++;
        }
      }
      if (mounted) setState(() => _done++);
    }

    // Device-uploaded photos: store + persist each result so detected diseases
    // show under the photo and are saved.
    for (final row in widget.uploadedRows) {
      final id = row['id'] as String?;
      final url = (row['image_url'] as String?) ?? '';
      if (id == null || url.isEmpty) {
        failed++;
      } else {
        try {
          final res = await hf.predictByUrl(url);
          final diseases = _diseaseLabels(res);
          final result = <String, dynamic>{
            'analyzed': true,
            'has_disease': diseases.isNotEmpty,
            'diseases': diseases,
            'detection_count': diseases.length,
            'analyzed_at': DateTime.now().toUtc().toIso8601String(),
          };
          ref.read(campaignImageAnalysisProvider.notifier).set(id, result);
          await supa.saveCampaignImageAnalysis(
              campaignImageId: id, analysis: result);
          tally(diseases);
        } catch (_) {
          failed++;
        }
      }
      if (mounted) setState(() => _done++);
    }

    widget.onChanged();
    if (mounted) {
      setState(() => _running = false);
      final clear = analyzed - withDisease;
      final failNote = failed > 0 ? ' · $failed could not be analyzed' : '';
      final msg = agg.isEmpty
          ? 'Analysis complete — no diseases found in $analyzed image${analyzed == 1 ? '' : 's'}$failNote.'
          : 'Analysis complete — ${agg.length} disease type${agg.length == 1 ? '' : 's'} found · '
              '$withDisease with findings · $clear clear$failNote. See results under each photo.';
      _toast(msg, agg.isEmpty ? AppColors.greenDeep : AppColors.warn);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      content: Text(msg,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 24,
      borderColor: AppColors.green.withAlpha(70),
      child: Row(
        children: [
          const Icon(Icons.biotech_rounded, color: AppColors.green, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Image Analysis',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  _running
                      ? 'Analyzing $_done of $_total crop image${_total == 1 ? '' : 's'}…'
                      : _imageCount == 0
                          ? 'Add crop images first, then run analysis to check for disease.'
                          : 'Run the crop-disease model on all $_imageCount image${_imageCount == 1 ? '' : 's'} in this campaign.',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textDim, fontSize: 13, height: 1.4),
                ),
                if (_running) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _total == 0 ? null : _done / _total,
                      minHeight: 6,
                      backgroundColor: AppColors.surface2,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: (_running || _imageCount == 0) ? null : _analyzeAll,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.biotech_rounded),
            label: Text(_running ? 'Analyzing…' : 'Analyze Images'),
          ),
        ],
      ),
    );
  }
}

/// Grid of crop photos uploaded from the user's device (no flight capture).
class _UploadedImagesGrid extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> rows;
  final VoidCallback onRemoved;

  /// Persisted per-image Image Analysis results keyed by campaign-image id.
  final Map<String, dynamic> persistedAnalysis;

  const _UploadedImagesGrid({
    required this.rows,
    required this.onRemoved,
    this.persistedAnalysis = const {},
  });

  @override
  ConsumerState<_UploadedImagesGrid> createState() =>
      _UploadedImagesGridState();
}

class _UploadedImagesGridState extends ConsumerState<_UploadedImagesGrid> {
  final _removing = <String>{};

  Future<void> _remove(String rowId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Remove this photo?',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900)),
        content: const Text('This removes the uploaded photo from this campaign.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _removing.add(rowId));
    try {
      await ref.read(supabaseServiceProvider).removeCampaignImage(rowId);
      widget.onRemoved();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not remove the photo. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _removing.remove(rowId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(campaignImageAnalysisProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 760
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.rows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 250,
          ),
          itemBuilder: (context, i) {
            final row = widget.rows[i];
            final id = row['id'] as String;
            final url = (row['image_url'] as String?) ?? '';
            final removing = _removing.contains(id);

            // Analysis result: prefer the persisted campaign analysis, then a
            // saved row value, then the in-session result from the last run.
            final persisted = widget.persistedAnalysis[id];
            final analysis = (persisted is Map
                    ? Map<String, dynamic>.from(persisted)
                    : null) ??
                (row['analysis_json'] is Map
                    ? Map<String, dynamic>.from(row['analysis_json'] as Map)
                    : null) ??
                session[id];

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppColors.surface2,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.surface2,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.textFaint),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Uploaded',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: GestureDetector(
                              onTap: removing ? null : () => _remove(id),
                              child: const CircleAvatar(
                                radius: 13,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close_rounded,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                          if (removing)
                            Container(
                              color: Colors.black.withAlpha(90),
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _AnalysisResultStrip(analysis: analysis),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// The disease-result strip shown under an uploaded crop photo.
class _AnalysisResultStrip extends StatelessWidget {
  final Map<String, dynamic>? analysis;

  const _AnalysisResultStrip({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    if (a == null || a['analyzed'] != true) {
      return _wrap(
        icon: Icons.biotech_outlined,
        color: AppColors.textFaint,
        child: Text(
          'Not analyzed yet',
          style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 11.5,
              fontWeight: FontWeight.w700),
        ),
      );
    }
    final diseases = (a['diseases'] as List?)?.cast<dynamic>() ?? const [];
    if (diseases.isEmpty) {
      return _wrap(
        icon: Icons.verified_rounded,
        color: AppColors.green,
        child: Text(
          'No disease · Healthy',
          style: GoogleFonts.spaceGrotesk(
              color: AppColors.greenDeep,
              fontSize: 11.5,
              fontWeight: FontWeight.w800),
        ),
      );
    }
    // Confidence / severity meta (shown when persisted analysis carries them).
    final conf = a['confidence'];
    final sev = a['severity'];
    final needsReview = a['needs_review'] == true;
    final metaParts = <String>[
      if (conf is num) '${(conf * 100).round()}% confidence',
      if (sev is String && sev.isNotEmpty) '${sev[0].toUpperCase()}${sev.substring(1)} severity',
    ];
    final meta = needsReview
        ? 'Low confidence · review'
        : metaParts.join(' · ');
    return _wrap(
      icon: Icons.coronavirus_rounded,
      color: needsReview ? AppColors.warn : AppColors.crit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diseases.join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
                color: needsReview ? AppColors.warn : AppColors.crit,
                fontSize: 11.5,
                fontWeight: FontWeight.w800),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  Widget _wrap(
      {required IconData icon, required Color color, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Environmental context cards (soil moisture, temperature/weather, GPS/zone).
/// Values are supplemental field estimates when live sensors are unavailable.
class _EnvContextCards extends StatelessWidget {
  final Map<String, dynamic> env;

  const _EnvContextCards({required this.env});

  String? _str(dynamic v) => v?.toString();

  @override
  Widget build(BuildContext context) {
    final soil = env['soil_moisture_pct'];
    final temp = env['temperature_c'];
    final weather = _str(env['weather_condition']);
    final humidity = env['humidity_pct'];
    final lat = env['gps_lat'];
    final lng = env['gps_lng'];
    final zone = _str(env['field_zone']);
    final isSupplemental = env['source'] == 'supplemental';
    final note = isSupplemental ? 'Estimated field value' : 'Live reading';

    final cards = <Widget>[
      _EnvCard(
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF2F8FE0),
        label: 'Soil Moisture',
        value: soil != null ? '$soil%' : '—',
        sub: soil != null ? _soilBand(soil) : 'Not recorded',
        note: note,
      ),
      _EnvCard(
        icon: Icons.thermostat_rounded,
        color: AppColors.warn,
        label: 'Temperature & Weather',
        value: temp != null ? '$temp°C' : '—',
        sub: [
          if (weather != null) weather,
          if (humidity != null) 'Humidity $humidity%',
        ].join(' · '),
        note: note,
      ),
      _EnvCard(
        icon: Icons.place_rounded,
        color: AppColors.green,
        label: 'Field Location',
        value: zone ?? 'Field',
        sub: (lat != null && lng != null)
            ? '$lat, $lng'
            : 'Coordinates not available',
        note: note,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 720) {
        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              cards[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    });
  }

  static String _soilBand(dynamic pct) {
    final v = (pct is num) ? pct.toDouble() : double.tryParse('$pct') ?? 0;
    if (v < 25) return 'Dry — check irrigation';
    if (v <= 45) return 'Adequate for rice';
    if (v <= 60) return 'Moist';
    return 'Very wet — watch drainage';
  }
}

class _EnvCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final String note;

  const _EnvCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 12, color: AppColors.textFaint),
              const SizedBox(width: 4),
              Text(
                note,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textFaint,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CampaignView campaign;
  final bool gpsAvailable;
  final bool gpsKnown;
  final bool isManual;

  const _SummaryCard({
    required this.campaign,
    required this.gpsAvailable,
    required this.gpsKnown,
    required this.isManual,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(
                  campaign.isDroneFlight
                      ? Icons.flight_takeoff_rounded
                      : Icons.workspaces_rounded,
                  'Source',
                  campaign.sourceLabel),
              if (campaign.cropType != null)
                _Chip(Icons.grass_rounded, 'Crop', campaign.cropType!),
              if (campaign.fieldName != null)
                _Chip(Icons.terrain_rounded, 'Field', campaign.fieldName!),
              _Chip(Icons.photo_library_rounded, 'Crop images',
                  '${campaign.imageCount}'),
              _Chip(Icons.verified_rounded, 'Analyzed',
                  '${campaign.analyzedCount} of ${campaign.imageCount}'),
              _Chip(
                Icons.health_and_safety_rounded,
                'Disease findings',
                campaign.hasDiagnosis
                    ? '${campaign.diseaseCount}'
                    : 'No diagnosis yet',
              ),
              if (!isManual)
                _Chip(
                  Icons.place_rounded,
                  'GPS',
                  !gpsKnown
                      ? 'Checking…'
                      : (gpsAvailable ? 'Available' : 'Not connected yet'),
                ),
              _Chip(
                Icons.description_rounded,
                'Report',
                campaign.reportAvailable ? 'Ready' : 'Not generated yet',
              ),
            ],
          ),
          if (campaign.imageCount > 0 && campaign.analyzedCount == 0) ...[
            const SizedBox(height: 14),
            Text(
              'Analysis not run yet. Open an image below and run Image Analysis to get real crop health results.',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportSection extends ConsumerStatefulWidget {
  final CampaignView campaign;
  final List<Detection> detections;

  const _ReportSection({required this.campaign, required this.detections});

  @override
  ConsumerState<_ReportSection> createState() => _ReportSectionState();
}

class _ReportSectionState extends ConsumerState<_ReportSection> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final report = await generateCampaignReport(
        ref,
        campaign: widget.campaign,
        detections: widget.detections,
      );
      if (!mounted) return;
      if (report.id == 'unsaved') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
              'Report created. Set up the reports table to save it permanently.'),
        ));
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReportViewScreen(report: report)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
              'The AI Advisor could not prepare the report. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canReport = widget.campaign.canGenerateReport;
    return AgriGlassCard(
      radius: 24,
      borderColor: canReport ? AppColors.green.withAlpha(70) : null,
      child: Row(
        children: [
          Icon(Icons.description_rounded,
              color: canReport ? AppColors.green : AppColors.textFaint,
              size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crop report',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _generating
                      ? 'AI Advisor is preparing your crop report…'
                      : canReport
                          ? 'Real analyzed images are available. Generate a crop report for this campaign.'
                          : 'No diagnosis yet. Run Image Analysis on at least one crop image to enable a real report.',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: (!canReport || _generating) ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.note_add_rounded),
            label: Text(_generating ? 'Generating…' : 'Generate Report'),
          ),
        ],
      ),
    );
  }
}

class _ImageGrid extends ConsumerStatefulWidget {
  final List<FlightCapture> captures;
  final List<Detection> detections;
  final CampaignView campaign;
  final VoidCallback onChanged;
  final void Function(FlightCapture)? onRemove;

  const _ImageGrid({
    required this.captures,
    required this.detections,
    required this.campaign,
    required this.onChanged,
    this.onRemove,
  });

  @override
  ConsumerState<_ImageGrid> createState() => _ImageGridState();
}

class _ImageGridState extends ConsumerState<_ImageGrid> {
  int? _analyzingCaptureId;

  List<Detection> _forCapture(int captureId) =>
      widget.detections.where((d) => d.flightCaptureId == captureId).toList();

  String _severity(double confidence) {
    if (confidence >= 0.75) return 'high';
    if (confidence >= 0.5) return 'moderate';
    return 'low';
  }

  Future<void> _runAnalysis(FlightCapture capture) async {
    if ((capture.imageUrl ?? '').isEmpty) {
      _toast('This image has no source file to analyze.', AppColors.warn);
      return;
    }
    setState(() => _analyzingCaptureId = capture.id);
    try {
      await ref.read(supabaseServiceProvider).requestAnalysis(capture.id);
      final res = await ref.read(huggingFaceServiceProvider).predict(
            imageUrl: capture.imageUrl ?? '',
            flightCaptureId: capture.id,
            flightId: capture.flightId,
            imageIndex: capture.imageIndex,
          );
      final raw = res['detections'];
      final count = res['detections_count'] is int
          ? res['detections_count'] as int
          : raw is List
              ? raw.length
              : 0;
      widget.onChanged();
      if (mounted) {
        _toast(
          count == 0
              ? 'Image Analysis finished: no disease found.'
              : 'Image Analysis finished: $count finding(s) recorded.',
          AppColors.greenDeep,
        );
      }
    } catch (e) {
      if (mounted) {
        _toast('Image Analysis could not finish. Please try again.',
            AppColors.crit);
      }
    } finally {
      if (mounted) setState(() => _analyzingCaptureId = null);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Text(msg,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _openDiagnosis(FlightCapture capture, List<Detection> dets) {
    final top = dets.reduce((a, b) => a.confidence >= b.confidence ? a : b);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosisDetailScreen(
          imageUrl: capture.imageUrl ?? '',
          context: AiDetectionContext(
            captureId: capture.id.toString(),
            flightId: capture.flightId.toString(),
            diseaseName: top.label,
            confidence: top.confidence,
            severity: _severity(top.confidence),
            cropType: widget.campaign.cropType ?? 'rice',
            moisturePct: capture.moisturePct,
          ),
          detections: dets,
          title: 'Crop Diagnosis',
          sourceLabel: 'Drone capture · ${widget.campaign.name}',
        ),
      ),
    );
  }

  void _onTapCapture(FlightCapture capture) {
    final dets = _forCapture(capture.id);
    if (dets.isNotEmpty) {
      _openDiagnosis(capture, dets);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Image #${capture.imageIndex}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              capture.aiProcessed
                  ? 'This image was analyzed and no disease was found.'
                  : 'This image has not been analyzed yet. Run Image Analysis to get a real crop health result.',
              style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _runAnalysis(capture);
                },
                icon: const Icon(Icons.biotech_rounded),
                label: Text(capture.aiProcessed
                    ? 'Re-run Image Analysis'
                    : 'Run Image Analysis'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 760
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.captures.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, i) {
            final capture = widget.captures[i];
            final dets = _forCapture(capture.id);
            return Stack(
              children: [
                GalleryTile(
                  capture: capture,
                  isSelected: false,
                  detections: dets,
                  onTap: () => _onTapCapture(capture),
                  onLongPress: widget.onRemove == null
                      ? null
                      : () => widget.onRemove!(capture),
                ),
                if (widget.onRemove != null)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: GestureDetector(
                      onTap: () => widget.onRemove!(capture),
                      child: const CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                if (_analyzingCaptureId == capture.id)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(90),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Chip(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.green),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textFaint,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
