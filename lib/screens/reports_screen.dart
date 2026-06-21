import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/crop_report.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/report_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_ui.dart';
import '../widgets/asset_illustrations.dart';
import 'report_view_screen.dart';

/// Reports — real crop reports generated from real diagnosis/campaign data.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoMode = ref.watch(demoModeProvider);
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(reportsProvider);
            await ref.read(reportsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Banner Illustration Header
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.greenDeep.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      AppAssets.reportHeader,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                            color: AppColors.greenDeep.withValues(alpha: 0.2));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const PageHeader(
                  title: 'Reports',
                  subtitle:
                      'Farmer-ready crop reports generated from your real crop image analysis. Open a campaign and tap Generate Report to create one.',
                ),
                const SizedBox(height: 22),
                if (demoMode) ...[
                  const _DemoPreviewNotice(),
                  const SizedBox(height: 14),
                ],
                reportsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const EmptyStateCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Reports need connection',
                    message:
                        'Your crop reports could not be loaded. Check your connection and try again.',
                  ),
                  data: (reports) {
                    if (reports.isEmpty) {
                      return const EmptyStateCard(
                        icon: Icons.description_rounded,
                        title: 'No crop report yet',
                        message:
                            'No crop report yet. Open a campaign with analyzed crop images and tap Generate Report to create a real report.',
                        illustrationPath: AppAssets.emptyReports,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${reports.length} report${reports.length == 1 ? '' : 's'}',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.textDim,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final r in reports) ...[
                          _ReportRow(report: r),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final CropReport report;

  const _ReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final disease = report.reportJson['disease_result']?.toString();
    final severity = report.reportJson['severity']?.toString();
    final subtitleParts = <String>[
      if (report.reportJson['campaign_name'] != null)
        report.reportJson['campaign_name'].toString(),
      if (disease != null && disease.isNotEmpty) disease,
      if (severity != null && severity.isNotEmpty) severity,
    ];
    return AgriGlassCard(
      radius: 20,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReportViewScreen(report: report)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.article_rounded,
                color: AppColors.greenDeep, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.isEmpty
                      ? report.typeLabel
                      : subtitleParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TypePill(label: report.typeLabel),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;

  const _TypePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.green.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.green.withAlpha(55)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.greenDeep,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DemoPreviewNotice extends StatelessWidget {
  const _DemoPreviewNotice();

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 18,
      elevated: false,
      borderColor: AppColors.warn.withAlpha(90),
      child: Text(
        demoPreviewLabel,
        style: GoogleFonts.spaceGrotesk(
          color: AppColors.warn,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
