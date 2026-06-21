import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_assistant.dart';
import '../providers/flight_providers.dart';
import '../theme/app_colors.dart';

enum AiAction { explain, recommend, report, judge }

class AiAssistantPanel extends ConsumerStatefulWidget {
  final AiDetectionContext? context;

  const AiAssistantPanel({
    super.key,
    required this.context,
  });

  @override
  ConsumerState<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends ConsumerState<AiAssistantPanel> {
  AiAction? _loadingAction;
  AiExplanation? _explanation;
  AiRecommendation? _recommendation;
  AiReport? _report;
  AiJudgeSummary? _judgeSummary;
  String? _errorMessage;
  bool? _advisorReady;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    try {
      final health = await ref.read(aiAssistantServiceProvider).health();
      if (mounted) {
        setState(() {
          _advisorReady = health['anthropic_configured'] == true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _advisorReady = null;
        });
      }
    }
  }

  Future<void> _run(AiAction action) async {
    final contextPayload = widget.context;
    if (contextPayload == null) {
      setState(() {
        _errorMessage =
            'No crop image is selected yet. Check a crop image first, then ask the AI Advisor for guidance.';
      });
      return;
    }

    setState(() {
      _loadingAction = action;
      _errorMessage = null;
    });

    try {
      final service = ref.read(aiAssistantServiceProvider);
      switch (action) {
        case AiAction.explain:
          final result = await service.explain(contextPayload);
          if (mounted) setState(() => _explanation = result);
          break;
        case AiAction.recommend:
          final result = await service.recommend(contextPayload);
          if (mounted) setState(() => _recommendation = result);
          break;
        case AiAction.report:
          final result = await service.report(contextPayload);
          if (mounted) setState(() => _report = result);
          break;
        case AiAction.judge:
          final result = await service.judgeSummary(contextPayload);
          if (mounted) setState(() => _judgeSummary = result);
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDetection = widget.context != null;
    return _AiShell(
      title: 'AI Advisor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(ready: _advisorReady),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'Personalized guidance for the selected crop image.',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textDim, fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: [
              _StarterChip(
                  label: 'What disease is this?',
                  onTap: () => _run(AiAction.explain),
                  enabled: hasDetection && _loadingAction == null),
              _StarterChip(
                  label: 'What should I do today?',
                  onTap: () => _run(AiAction.recommend),
                  enabled: hasDetection && _loadingAction == null),
              _StarterChip(
                  label: 'Generate report',
                  onTap: () => _run(AiAction.report),
                  enabled: hasDetection && _loadingAction == null),
            ],
          ),
          const SizedBox(height: 10.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              _ActionButton(
                label: 'Explain Result',
                icon: Icons.psychology_alt_outlined,
                loading: _loadingAction == AiAction.explain,
                enabled: hasDetection && _loadingAction == null,
                onPressed: () => _run(AiAction.explain),
              ),
              _ActionButton(
                label: 'Get Recommendation',
                icon: Icons.agriculture_outlined,
                loading: _loadingAction == AiAction.recommend,
                enabled: hasDetection && _loadingAction == null,
                onPressed: () => _run(AiAction.recommend),
              ),
              _ActionButton(
                label: 'Generate Report',
                icon: Icons.description_outlined,
                loading: _loadingAction == AiAction.report,
                enabled: hasDetection && _loadingAction == null,
                onPressed: () => _run(AiAction.report),
              ),
              _ActionButton(
                label: 'Judge Summary',
                icon: Icons.slideshow_outlined,
                loading: _loadingAction == AiAction.judge,
                enabled: hasDetection && _loadingAction == null,
                onPressed: () => _run(AiAction.judge),
              ),
            ],
          ),
          if (!hasDetection) ...[
            const SizedBox(height: 10.0),
            const AiErrorState(
              message:
                  'No crop image is selected yet. Upload or select an image to get personalized guidance.',
            ),
          ],
          if (_loadingAction != null) ...[
            const SizedBox(height: 10.0),
            AiLoadingState(label: _loadingLabel(_loadingAction!)),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 10.0),
            AiErrorState(message: _errorMessage!),
          ],
          if (_explanation != null) ...[
            const SizedBox(height: 12.0),
            AiExplanationCard(explanation: _explanation!),
          ],
          if (_recommendation != null) ...[
            const SizedBox(height: 12.0),
            AiRecommendationCard(recommendation: _recommendation!),
          ],
          if (_report != null) ...[
            const SizedBox(height: 12.0),
            AiReportCard(report: _report!),
          ],
          if (_judgeSummary != null) ...[
            const SizedBox(height: 12.0),
            AiJudgeSummaryCard(summary: _judgeSummary!),
          ],
          const SizedBox(height: 10.0),
          Text(
            'AI guidance supports decision-making and does not replace expert agricultural advice.',
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.textFaint, fontSize: 10.0),
          ),
        ],
      ),
    );
  }

  String _loadingLabel(AiAction action) {
    switch (action) {
      case AiAction.explain:
        return 'AI Advisor is explaining the crop result...';
      case AiAction.recommend:
        return 'AI Advisor is preparing farmer guidance...';
      case AiAction.report:
        return 'AI Advisor is generating a crop health report...';
      case AiAction.judge:
        return 'AI Advisor is writing a judge-ready summary...';
    }
  }
}

class AiExplanationCard extends StatelessWidget {
  final AiExplanation explanation;

  const AiExplanationCard({super.key, required this.explanation});

  @override
  Widget build(BuildContext context) {
    return _AiResultCard(
      title: 'Crop Explanation',
      icon: Icons.psychology_alt_outlined,
      children: [
        _MetaLine('Disease', explanation.diseaseName),
        _MetaLine('Confidence',
            '${(explanation.confidence * 100).toStringAsFixed(1)}%'),
        _MetaLine('Severity', explanation.severity),
        _TextBlock('Summary', explanation.summary),
        _TextBlock('Farmer-Friendly Explanation',
            explanation.farmerFriendlyExplanation),
        _BulletBlock('Likely Causes', explanation.likelyCauses),
        _BulletBlock('Immediate Actions', explanation.immediateActions),
        _BulletBlock('Organic Treatment', explanation.organicTreatment),
        _BulletBlock('Chemical Treatment', explanation.chemicalTreatment),
        _BulletBlock('Prevention Tips', explanation.preventionTips),
        _TextBlock('Confidence Disclaimer', explanation.confidenceDisclaimer),
        _TextBlock('Expert Escalation', explanation.expertEscalation),
      ],
    );
  }
}

class AiRecommendationCard extends StatelessWidget {
  final AiRecommendation recommendation;

  const AiRecommendationCard({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return _AiResultCard(
      title: 'Farmer Recommendation',
      icon: Icons.agriculture_outlined,
      children: [
        _MetaLine('Urgency', recommendation.urgency.toUpperCase()),
        _TextBlock('Recommended Next Step', recommendation.recommendedNextStep),
        _BulletBlock('Organic Options', recommendation.organicOptions),
        _BulletBlock('Chemical Options', recommendation.chemicalOptions),
        _BulletBlock('Prevention', recommendation.prevention),
        _TextBlock('When To Call Expert', recommendation.whenToCallExpert),
      ],
    );
  }
}

class AiReportCard extends StatelessWidget {
  final AiReport report;

  const AiReportCard({super.key, required this.report});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: report.reportMarkdown));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crop health report copied.'),
        backgroundColor: AppColors.greenDeep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generatedAt = report.reportJson['generated_at']?.toString();
    return _AiResultCard(
      title: 'Crop Health Report',
      icon: Icons.description_outlined,
      trailing: IconButton(
        tooltip: 'Copy report',
        onPressed: () => _copy(context),
        icon: const Icon(Icons.copy_all_outlined,
            color: AppColors.green, size: 18.0),
      ),
      children: [
        _TextBlock('Title', report.title),
        if (generatedAt != null && generatedAt.isNotEmpty)
          _MetaLine('Generated', generatedAt),
        SelectableText(
          report.reportMarkdown,
          style: GoogleFonts.spaceGrotesk(
              color: AppColors.text, fontSize: 11.5, height: 1.35),
        ),
      ],
    );
  }
}

class AiJudgeSummaryCard extends StatelessWidget {
  final AiJudgeSummary summary;

  const AiJudgeSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return _AiResultCard(
      title: 'Showcase Summary',
      icon: Icons.slideshow_outlined,
      children: [
        _TextBlock('One-Liner', summary.oneLiner),
        _TextBlock('What Happened', summary.whatHappened),
        _TextBlock('Why It Matters', summary.whyItMatters),
        _TextBlock('What Farmer Should Do', summary.whatFarmerShouldDo),
        _TextBlock(
            'Demo Story',
            summary.technicalPipeline
                .replaceAll('Supabase', 'Cloud Sync')
                .replaceAll('YOLOv8n', 'Image Analysis')
                .replaceAll('Claude explanation', 'AI Advisor')
                .replaceAll('Drone image', 'Crop image')),
      ],
    );
  }
}

class AiLoadingState extends StatelessWidget {
  final String label;

  const AiLoadingState({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: _box(AppColors.info),
      child: Row(
        children: [
          const SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(
                color: AppColors.info, strokeWidth: 2.0),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class AiErrorState extends StatelessWidget {
  final String message;

  const AiErrorState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: _box(AppColors.crit),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.crit, size: 18.0),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text, fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _AiShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: _box(AppColors.green),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.green.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.green, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          child,
        ],
      ),
    );
  }
}

class _StarterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _StarterChip({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: enabled ? onTap : null,
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.line),
      labelStyle: GoogleFonts.spaceGrotesk(
        color: AppColors.greenDeep,
        fontSize: 11.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AiResultCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _AiResultCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: _box(AppColors.lineBright),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.green, size: 16.0),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10.0),
          ...children,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150.0,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.lineBright),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
        icon: loading
            ? const SizedBox(
                width: 14.0,
                height: 14.0,
                child: CircularProgressIndicator(
                    color: AppColors.green, strokeWidth: 2.0),
              )
            : Icon(icon, size: 15.0),
        label: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold, fontSize: 10.5),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool? ready;

  const _StatusChip({required this.ready});

  @override
  Widget build(BuildContext context) {
    final color = ready == true
        ? AppColors.green
        : ready == false
            ? AppColors.warn
            : AppColors.crit;
    final label = ready == true
        ? 'Ready'
        : ready == false
            ? 'Needs Setup'
            : 'Connection Issue';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.10).toInt()),
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(color: color.withAlpha((255 * 0.40).toInt())),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetaLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          style:
              GoogleFonts.spaceGrotesk(color: AppColors.text, fontSize: 11.5),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  color: AppColors.textFaint, fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String title;
  final String text;

  const _TextBlock(this.title, this.text);

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textFaint,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.text, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _BulletBlock extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BulletBlock(this.title, this.items);

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.trim().isNotEmpty).toList();
    if (visibleItems.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textFaint,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          ...visibleItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 3.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('- ', style: TextStyle(color: AppColors.green)),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.spaceGrotesk(
                          color: AppColors.text, fontSize: 11.5, height: 1.32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _box(Color color) {
  return BoxDecoration(
    color: AppColors.glass,
    borderRadius: BorderRadius.circular(18.0),
    border: Border.all(color: color.withAlpha((255 * 0.25).toInt())),
    boxShadow: [
      BoxShadow(
        color: AppColors.greenDeep.withAlpha((255 * 0.06).toInt()),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
