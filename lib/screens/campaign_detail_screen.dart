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
              const SizedBox(height: 18),
              _AnalyzeImagesBar(
                captures: capturesAsync.asData?.value ?? const [],
                uploadedUrls: [
                  for (final r in uploadedRows)
                    if (r['image_url'] != null) r['image_url'] as String,
                ],
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
  final List<String> uploadedUrls;
  final VoidCallback onChanged;

  const _AnalyzeImagesBar({
    required this.captures,
    required this.uploadedUrls,
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

  int get _imageCount => widget.captures.length + widget.uploadedUrls.length;

  bool _isDisease(String label) =>
      !_healthy.contains(label.toLowerCase().trim().replaceAll(' ', '_'));

  void _collect(Map<String, dynamic> res, Map<String, int> diseases) {
    final dets = (res['detections'] as List?) ?? const [];
    var hasDisease = false;
    for (final d in dets) {
      if (d is! Map) continue;
      final label = (d['label'] ?? d['name'] ?? '').toString();
      if (label.isEmpty || !_isDisease(label)) continue;
      hasDisease = true;
      final pretty = label.replaceAll('_', ' ');
      diseases[pretty] = (diseases[pretty] ?? 0) + 1;
    }
    if (hasDisease) {
      _withDisease++;
    } else {
      _clear++;
    }
  }

  int _clear = 0;
  int _withDisease = 0;

  Future<void> _analyzeAll() async {
    if (_imageCount == 0) {
      _toast('No crop images to analyze yet.', AppColors.warn);
      return;
    }
    final hf = ref.read(huggingFaceServiceProvider);
    final supa = ref.read(supabaseServiceProvider);
    final diseases = <String, int>{};
    var analyzed = 0;
    var failed = 0;
    _clear = 0;
    _withDisease = 0;

    setState(() {
      _running = true;
      _done = 0;
      _total = _imageCount;
    });

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
          _collect(res, diseases);
          analyzed++;
        } catch (_) {
          failed++;
        }
      }
      if (mounted) setState(() => _done++);
    }

    for (final url in widget.uploadedUrls) {
      try {
        final res = await hf.predictByUrl(url);
        _collect(res, diseases);
        analyzed++;
      } catch (_) {
        failed++;
      }
      if (mounted) setState(() => _done++);
    }

    widget.onChanged();
    if (mounted) {
      setState(() => _running = false);
      _showResult(analyzed, failed, diseases);
    }
  }

  void _showResult(int analyzed, int failed, Map<String, int> diseases) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(
              diseases.isEmpty
                  ? Icons.verified_rounded
                  : Icons.warning_amber_rounded,
              color: diseases.isEmpty ? AppColors.green : AppColors.warn,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Image Analysis complete',
                  style:
                      GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyzed $analyzed image${analyzed == 1 ? '' : 's'}'
              '${failed > 0 ? ' · $failed could not be analyzed' : ''}.',
              style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (diseases.isEmpty)
              Text(
                'No diseases detected — your crops look healthy. '
                '$_clear image${_clear == 1 ? '' : 's'} checked clear.',
                style: GoogleFonts.spaceGrotesk(
                    color: AppColors.greenDeep,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4),
              )
            else ...[
              Text('Diseases detected:',
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 8),
              ...diseases.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.coronavirus_rounded,
                            size: 16, color: AppColors.crit),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${e.key} — ${e.value} finding${e.value == 1 ? '' : 's'}',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              Text(
                '$_withDisease image${_withDisease == 1 ? '' : 's'} with findings · '
                '$_clear clear.',
                style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim, fontSize: 12.5),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
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

  const _UploadedImagesGrid({required this.rows, required this.onRemoved});

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
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, i) {
            final row = widget.rows[i];
            final id = row['id'] as String;
            final url = (row['image_url'] as String?) ?? '';
            final removing = _removing.contains(id);
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
            );
          },
        );
      },
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
