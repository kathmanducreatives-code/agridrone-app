import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/crop_report.dart';
import '../providers/flight_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_ui.dart';
import '../widgets/global_ai_advisor.dart';

/// Read-only viewer for a generated crop report. Renders only real report
/// content — never the AI provider or model name.
class ReportViewScreen extends ConsumerWidget {
  final CropReport report;

  const ReportViewScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final md = report.reportMarkdown ?? '';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: Text(report.typeLabel,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Copy report',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: md));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Report copied.')));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypePill(label: report.typeLabel),
                      const Spacer(),
                      if (report.createdAt != null)
                        Text(
                          _formatDate(report.createdAt!),
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.textFaint,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.title,
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AgriGlassCard(
                    radius: 24,
                    child: md.trim().isEmpty
                        ? Text(
                            'This report has no written content.',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppColors.textDim),
                          )
                        : AdvisorMarkdown(
                            data: md,
                            baseStyle: GoogleFonts.spaceGrotesk(
                              color: AppColors.text,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  const _MissingDataNote(),
                  const SizedBox(height: 14),
                  _ReportFeedback(report: report),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _MissingDataNote extends StatelessWidget {
  const _MissingDataNote();

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 18,
      elevated: false,
      borderColor: AppColors.warn.withAlpha(60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.warn, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This report uses real crop image analysis. GPS location, local weather and field boundary are included only when those are connected — they are not part of this report yet.',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportFeedback extends ConsumerStatefulWidget {
  final CropReport report;

  const _ReportFeedback({required this.report});

  @override
  ConsumerState<_ReportFeedback> createState() => _ReportFeedbackState();
}

class _ReportFeedbackState extends ConsumerState<_ReportFeedback> {
  String? _selected;

  Future<void> _send(String feedback) async {
    if (_selected != null) return;
    setState(() => _selected = feedback);
    try {
      await ref.read(aiAssistantServiceProvider).submitFeedback(
            targetType: 'report',
            targetId: widget.report.id,
            feedback: feedback,
          );
    } catch (_) {
      // Optional feedback should never interrupt report viewing.
    }
  }

  @override
  Widget build(BuildContext context) {
    const options = [
      ('Helpful', 'helpful', Icons.thumb_up_alt_outlined),
      ('Not helpful', 'not_helpful', Icons.thumb_down_alt_outlined),
      ('Needs expert review', 'needs_expert_review', Icons.person_search_rounded),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ActionChip(
            onPressed: _selected == null ? () => _send(o.$2) : null,
            avatar: Icon(o.$3, size: 15),
            label: Text(_selected == o.$2 ? 'Sent' : o.$1),
            labelStyle: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;

  const _TypePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.green.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.green.withAlpha(60)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.greenDeep,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
