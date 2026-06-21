import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_assistant.dart';
import '../models/detection.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_ui.dart';
import '../widgets/ai_assistant_panel.dart';
import '../widgets/bbox_overlay.dart';

class DiagnosisDetailScreen extends ConsumerWidget {
  final String imageUrl;
  final AiDetectionContext context;
  final List<Detection> detections;
  final String title;
  final String sourceLabel;
  final String? locationLabel;
  final String? recommendation;
  final bool isDemoPreview;

  const DiagnosisDetailScreen({
    super.key,
    required this.imageUrl,
    required this.context,
    required this.detections,
    this.title = 'Crop Diagnosis',
    this.sourceLabel = 'Drone capture',
    this.locationLabel,
    this.recommendation,
    this.isDemoPreview = false,
  });

  factory DiagnosisDetailScreen.demo() {
    final sample = demoDiagnosisSample;
    final detection = Detection(
      id: -1,
      flightCaptureId: -1,
      flightId: 42,
      imageIndex: 7,
      label: sample.diseaseName,
      confidence: sample.confidence,
      bboxX1: sample.bbox[0] * 1600,
      bboxY1: sample.bbox[1] * 1200,
      bboxX2: sample.bbox[2] * 1600,
      bboxY2: sample.bbox[3] * 1200,
      inferenceTimeMs: 248,
      detectedAt: DateTime.now(),
      imageUrl: sample.imageUrl,
    );
    return DiagnosisDetailScreen(
      imageUrl: sample.imageUrl,
      context: AiDetectionContext(
        diseaseName: sample.diseaseName,
        confidence: sample.confidence,
        severity: sample.severity,
        cropType: sample.cropType.toLowerCase(),
        moisturePct: sample.moisturePct,
        bbox: sample.bbox,
      ),
      detections: [detection],
      title: sample.reportTitle,
      sourceLabel: 'Demo crop image',
      locationLabel: sample.locationLabel,
      recommendation: sample.recommendation,
      isDemoPreview: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(globalAiAdvisorProvider.notifier).setSelectedDiagnosis(
            context: this.context,
            imageUrl: imageUrl,
            imageLabel: sourceLabel,
            pageOverride: 'Diagnosis',
          );
    });

    final isWide = MediaQuery.sizeOf(context).width >= 1100;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(globalAiAdvisorProvider.notifier).clearPageOverride();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7FBF6), Colors.white, Color(0xFFEFF8EF)],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.greenDeep,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PageHeader(
                          title: title,
                          subtitle:
                              'Your crop image has been checked. Review the result, action plan, treatment options, and report tools.',
                          trailing:
                              SeverityBadge(severity: this.context.severity),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (isDemoPreview) ...[
                    const _DemoPreviewNotice(),
                    const SizedBox(height: 18),
                  ],
                  isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _ImagePanel(this)),
                            const SizedBox(width: 18),
                            Expanded(flex: 4, child: _DiagnosisColumn(this)),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 360,
                              child: AiAssistantPanel(context: this.context),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _ImagePanel(this),
                            const SizedBox(height: 18),
                            _DiagnosisColumn(this),
                            const SizedBox(height: 18),
                            AiAssistantPanel(context: this.context),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  final DiagnosisDetailScreen screen;

  const _ImagePanel(this.screen);

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 28,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: BboxOverlay(
                detections: screen.detections,
                child: CachedNetworkImage(
                  imageUrl: screen.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.surface2,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.green),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surface2,
                    child: const Icon(Icons.image_not_supported_rounded,
                        color: AppColors.textFaint, size: 48),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SystemStatusChip(
                label: 'Source',
                status: screen.sourceLabel,
                ok: true,
                icon: Icons.flight_takeoff_rounded,
              ),
              if (screen.locationLabel != null)
                SystemStatusChip(
                  label: 'Field',
                  status: screen.locationLabel!,
                  ok: true,
                  icon: Icons.place_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoPreviewNotice extends StatelessWidget {
  const _DemoPreviewNotice();

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 22,
      borderColor: AppColors.warn.withAlpha(90),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warn),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              demoPreviewLabel,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisColumn extends StatelessWidget {
  final DiagnosisDetailScreen screen;

  const _DiagnosisColumn(this.screen);

  @override
  Widget build(BuildContext context) {
    final confidencePct = (screen.context.confidence * 100).toStringAsFixed(0);
    return Column(
      children: [
        AgriGlassCard(
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.health_and_safety_rounded,
                      color: AppColors.green, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Disease detected',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                screen.context.diseaseName,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.greenDeep,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniContextCard(
                      label: 'AI confidence',
                      value: '$confidencePct%',
                      icon: Icons.insights_rounded,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniContextCard(
                      label: 'Moisture',
                      value: screen.context.moisturePct == null
                          ? 'Unknown'
                          : '${screen.context.moisturePct!.toStringAsFixed(0)}%',
                      icon: Icons.water_drop_rounded,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'AI guidance supports decision-making and does not replace expert agricultural advice.',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AgriGlassCard(
          radius: 24,
          borderColor: AppColors.warn.withAlpha(80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded,
                      color: AppColors.warn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'What should I do next?',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                screen.recommendation ??
                    'Ask the AI Advisor for a farmer-friendly recommendation based on this selected crop result.',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _QuestionChip('What disease is this?'),
                  _QuestionChip('How serious is it?'),
                  _QuestionChip('What should I do today?'),
                  _QuestionChip('When should I contact an expert?'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AgriGlassCard(
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.checklist_rounded, color: AppColors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Farmer action plan',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _ActionLine('Do this today',
                  'Inspect nearby plants and remove heavily affected leaves where practical.'),
              const _ActionLine('Watch for these signs',
                  'New brown leaf spots, yellow rings, or symptoms spreading to nearby rows.'),
              const _ActionLine('When to ask an expert',
                  'If symptoms spread quickly or more than one-third of plants look affected.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AgriGlassCard(
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.spa_rounded, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Treatment options',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _ActionLine('Organic options',
                  'Improve airflow, drainage, and plant nutrition. Neem-based sprays may help where locally recommended.'),
              const _ActionLine('Chemical guidance',
                  'Use only locally approved fungicide categories and follow product labels and local agricultural guidelines.'),
              const _ActionLine('Safety note',
                  'Avoid unsafe dosage advice and confirm treatment with an agriculture expert when possible.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AgriGlassCard(
          radius: 24,
          borderColor: AppColors.green.withAlpha(80),
          child: Row(
            children: [
              const Icon(Icons.description_rounded,
                  color: AppColors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Create a crop health report to share with a teacher, judge, farmer, or agriculture expert.',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionLine extends StatelessWidget {
  final String title;
  final String body;

  const _ActionLine(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.greenDeep,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniContextCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniContextCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionChip extends StatelessWidget {
  final String label;

  const _QuestionChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.line),
      labelStyle: GoogleFonts.spaceGrotesk(
        color: AppColors.greenDeep,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
