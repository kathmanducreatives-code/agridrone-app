import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_assistant.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/farmer_profile_provider.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_ui.dart';
import '../widgets/asset_illustrations.dart';
import '../widgets/ai_assistant_panel.dart';

class AiAdvisorScreen extends ConsumerWidget {
  const AiAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoMode = ref.watch(demoModeProvider);
    final sample = demoDiagnosisSample;
    final advisorContext = demoMode
        ? AiDetectionContext(
            diseaseName: sample.diseaseName,
            confidence: sample.confidence,
            severity: sample.severity,
            cropType: sample.cropType.toLowerCase(),
            moisturePct: sample.moisturePct,
            bbox: sample.bbox,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'AI Advisor',
                subtitle:
                    'Ask for simple crop guidance, treatment options, and report-ready explanations based on the selected crop image.',
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1060;
                  final chat = _AdvisorWelcome(advisorContext: advisorContext);
                  final side = _AdvisorContextPanel(
                    demoMode: demoMode,
                    sample: sample,
                  );
                  if (!wide) {
                    return Column(
                      children: [
                        side,
                        const SizedBox(height: 16),
                        chat,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: chat),
                      const SizedBox(width: 18),
                      SizedBox(width: 360, child: side),
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
}

class _AdvisorWelcome extends StatelessWidget {
  final AiDetectionContext? advisorContext;

  const _AdvisorWelcome({required this.advisorContext});

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 30,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.green.withAlpha(28),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green.withAlpha(80)),
                ),
                child: const Icon(Icons.eco_rounded, color: AppColors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, I’m your AgriDrone AI Advisor.',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'I can explain crop disease, suggest next steps, and help you prepare a farmer report.',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.textDim,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _PromptChip('What should I do today?'),
              _PromptChip('Explain the latest crop result'),
              _PromptChip('How serious is this disease?'),
              _PromptChip('Give me organic treatment options'),
              _PromptChip('Create a farmer report'),
              _PromptChip('Should I retake the image?'),
            ],
          ),
          const SizedBox(height: 20),
          AiAssistantPanel(context: advisorContext),
        ],
      ),
    );
  }
}

class _AdvisorContextPanel extends StatelessWidget {
  final bool demoMode;
  final DemoDiagnosisSample sample;

  const _AdvisorContextPanel({
    required this.demoMode,
    required this.sample,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (demoMode) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: sample.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.surface2,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.green),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surface2,
                    child: const Icon(Icons.image_rounded,
                        color: AppColors.textFaint),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              demoPreviewLabel,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.warn,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else
            const EmptyStateCard(
              icon: Icons.image_search_rounded,
              title: 'No crop image selected',
              message:
                  'Upload or select a crop image to get personalized guidance.',
              illustrationPath: AppAssets.emptyCropImages,
            ),
          const SizedBox(height: 16),
          Text(
            demoMode ? 'Sample crop context' : 'No crop image selected',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (demoMode) ...[
            _ContextLine('Crop', sample.cropType),
            _ContextLine('Result', sample.diseaseName),
            _ContextLine('Severity', sample.severity),
            _ContextLine(
              'Confidence',
              '${(sample.confidence * 100).toStringAsFixed(0)}% useful for triage',
            ),
            _ContextLine(
              'Moisture',
              '${sample.moisturePct.toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 12),
            const SeverityBadge(severity: 'moderate'),
          ] else
            Text(
              'Upload or select a crop image to get personalized guidance.',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontSize: 14,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextLine extends StatelessWidget {
  final String label;
  final String value;

  const _ContextLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textFaint,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends ConsumerWidget {
  final String label;

  const _PromptChip(this.label);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionChip(
      onPressed: () {
        final contextPayload = ref.read(aiAdvisorAppContextProvider);
        ref.read(globalAiAdvisorProvider.notifier).open();
        final language = ref.read(farmerProfileProvider).language;
        ref
            .read(globalAiAdvisorProvider.notifier)
            .sendMessage(label, contextPayload, language: language);
      },
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.line),
      labelStyle: GoogleFonts.spaceGrotesk(
        color: AppColors.greenDeep,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
