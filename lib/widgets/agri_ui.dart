import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class AgriGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool elevated;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AgriGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.elevated = true,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? AppColors.line),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: AppColors.greenDeep.withAlpha(18),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: content),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textDim,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? helper;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.green,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: icon, color: color),
              const Spacer(),
              Icon(Icons.trending_up_rounded, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 8),
            Text(
              helper!,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textFaint,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SystemStatusChip extends StatelessWidget {
  final String label;
  final String status;
  final bool ok;
  final IconData icon;

  const SystemStatusChip({
    super.key,
    required this.label,
    required this.status,
    required this.ok,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.green : AppColors.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(
            '$label: $status',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  final String severity;

  const SeverityBadge({super.key, required this.severity});

  static Color colorFor(String severity) {
    final normalized = severity.toLowerCase();
    if (normalized.contains('high')) return AppColors.crit;
    if (normalized.contains('moderate') || normalized.contains('medium')) {
      return AppColors.warn;
    }
    if (normalized.contains('low')) return AppColors.teal;
    if (normalized.contains('healthy')) return AppColors.green;
    return AppColors.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        severity.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class CropHealthScoreCard extends StatelessWidget {
  final int score;
  final String summary;
  final VoidCallback? onStartDemo;

  const CropHealthScoreCard({
    super.key,
    required this.score,
    required this.summary,
    this.onStartDemo,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 28,
      borderColor: AppColors.green.withAlpha(80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(icon: Icons.eco_rounded, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Crop Health Score',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$score',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.greenDeep,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: score / 100,
              color: AppColors.green,
              backgroundColor: AppColors.green.withAlpha(30),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            summary,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (onStartDemo != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onStartDemo,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Demo Walkthrough'),
            ),
          ],
        ],
      ),
    );
  }
}

class PipelineStepper extends StatelessWidget {
  final List<String> steps;

  const PipelineStepper({
    super.key,
    this.steps = const [
      'Crop image',
      'Cloud sync',
      'Image analysis',
      'AI Advisor',
      'Crop report',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: 20,
      elevated: false,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 10,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _PipelineNode(label: steps[i], active: i < 4),
            if (i != steps.length - 1)
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: AppColors.green.withAlpha(160)),
          ],
        ],
      ),
    );
  }
}

class DemoStoryCard extends StatelessWidget {
  final VoidCallback? onOpenDiagnosis;

  const DemoStoryCard({super.key, this.onOpenDiagnosis});

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 24,
      borderColor: AppColors.teal.withAlpha(90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                  icon: Icons.auto_awesome_rounded, color: AppColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Demo Story',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'A crop image is captured, checked for disease risk, explained in simple language, and turned into a practical crop-health recommendation.',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onOpenDiagnosis,
            icon: const Icon(Icons.health_and_safety_rounded),
            label: const Text('Use Sample Diagnosis'),
          ),
        ],
      ),
    );
  }
}
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? illustrationPath;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationPath,
  });

  @override
  Widget build(BuildContext context) {
    return AgriGlassCard(
      radius: 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (illustrationPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                illustrationPath!,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _IconBubble(icon: icon, color: AppColors.green, size: 48),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _IconBubble(icon: icon, color: AppColors.green, size: 48),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconBubble({
    required this.icon,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(size / 2.8),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _PipelineNode extends StatelessWidget {
  final String label;
  final bool active;

  const _PipelineNode({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.unknown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: active ? AppColors.greenDeep : AppColors.textDim,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
