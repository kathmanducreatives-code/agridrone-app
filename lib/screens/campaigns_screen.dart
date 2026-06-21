import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/campaign_view.dart';
import '../providers/campaign_providers.dart';
import '../providers/flight_providers.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/agri_ui.dart';
import 'campaign_detail_screen.dart';

/// Crop Campaigns — groups crop images, a drone flight, diagnoses and reports.
///
/// Drone-flight campaigns are derived from real `flight_summary` data; manual
/// campaigns are stored in the `campaigns` table.
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFlightCampaignProvider);
    if (selected != null) {
      return CampaignDetailView(campaign: selected);
    }
    return const _CampaignsList();
  }
}

class _CampaignsList extends ConsumerWidget {
  const _CampaignsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(allCampaignsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(manualCampaignsProvider);
            ref.invalidate(flightCampaignsProvider);
            await ref.read(allCampaignsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Campaigns',
                  subtitle:
                      'Each drone flight is a crop campaign, and you can create your own. Open one to see its images, run analysis, ask the AI Advisor and prepare a report.',
                  trailing: ElevatedButton.icon(
                    onPressed: () => _createCampaign(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New Crop Campaign'),
                  ),
                ),
                const SizedBox(height: 22),
                campaignsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const EmptyStateCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Campaigns need connection',
                    message:
                        'Your crop campaigns could not be loaded. Check your connection and try again.',
                  ),
                  data: (campaigns) {
                    if (campaigns.isEmpty) {
                      return EmptyStateCard(
                        icon: Icons.workspaces_outlined,
                        title: 'No crop campaigns yet',
                        message:
                            'No crop campaigns yet. Create a manual campaign or sync a drone flight to start a real crop inspection project.',
                        actionLabel: 'New Crop Campaign',
                        onAction: () => _createCampaign(context, ref),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${campaigns.length} campaign${campaigns.length == 1 ? '' : 's'}',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.textDim,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CampaignGrid(campaigns: campaigns),
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

  Future<void> _createCampaign(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<CampaignView>(
      context: context,
      builder: (_) => const _NewCampaignDialog(),
    );
    if (created != null) {
      ref.read(selectedFlightCampaignProvider.notifier).open(created);
    }
  }
}

class _NewCampaignDialog extends ConsumerStatefulWidget {
  const _NewCampaignDialog();

  @override
  ConsumerState<_NewCampaignDialog> createState() => _NewCampaignDialogState();
}

class _NewCampaignDialogState extends ConsumerState<_NewCampaignDialog> {
  final _name = TextEditingController();
  final _crop = TextEditingController();
  final _field = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _crop.dispose();
    _field.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a campaign name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final row = await ref.read(supabaseServiceProvider).createManualCampaign(
            name: name,
            cropType: _crop.text,
            fieldName: _field.text,
            notes: _notes.text,
          );
      ref.invalidate(manualCampaignsProvider);
      final view = CampaignView.fromManual(
        row,
        imageCount: 0,
        analyzedCount: 0,
        diseaseCount: 0,
      );
      if (mounted) Navigator.pop(context, view);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the campaign. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        'New Crop Campaign',
        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field_('Campaign name *', _name, 'e.g. East field — June check'),
              _field_('Crop type', _crop, 'e.g. Rice'),
              _field_('Field name', _field, 'Optional'),
              _field_('Notes', _notes, 'Optional', maxLines: 2),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: GoogleFonts.spaceGrotesk(
                        color: AppColors.crit, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _field_(String label, TextEditingController c, String hint,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDim)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignGrid extends StatelessWidget {
  final List<CampaignView> campaigns;

  const _CampaignGrid({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 720
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: campaigns.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 232,
          ),
          itemBuilder: (context, i) => _CampaignCard(campaign: campaigns[i]),
        );
      },
    );
  }
}

class _CampaignCard extends ConsumerWidget {
  final CampaignView campaign;

  const _CampaignCard({required this.campaign});

  void _open(WidgetRef ref) {
    ref.read(selectedFlightCampaignProvider.notifier).open(campaign);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFlight = campaign.isDroneFlight;
    return AgriGlassCard(
      radius: 24,
      onTap: () => _open(ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.green.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    isFlight
                        ? Icons.flight_takeoff_rounded
                        : Icons.workspaces_rounded,
                    color: AppColors.greenDeep,
                    size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (campaign.cropType != null ||
                        campaign.fieldName != null)
                      Text(
                        [
                          if (campaign.cropType != null) campaign.cropType,
                          if (campaign.fieldName != null) campaign.fieldName,
                        ].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.textFaint,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              _SourcePill(label: campaign.sourceLabel),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat('Images', '${campaign.imageCount}'),
              _Stat('Analyzed', '${campaign.analyzedCount}'),
              _Stat(
                'Disease',
                campaign.hasDiagnosis ? '${campaign.diseaseCount}' : '—',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            campaign.hasDiagnosis
                ? '${campaign.diseaseCount} disease finding(s) recorded.'
                : campaign.analyzedCount > 0
                    ? 'Analyzed — no disease found.'
                    : campaign.imageCount == 0
                        ? 'No images yet. Open to add crop images.'
                        : 'No diagnosis yet. Open to run Image Analysis.',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textDim,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(ref),
                  icon: const Icon(Icons.open_in_full_rounded, size: 16),
                  label: const Text('Open'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Ask AI Advisor about this campaign',
                onPressed: () {
                  ref.read(globalAiAdvisorProvider.notifier).setCampaignContext(
                        campaign: campaign.toAdvisorCampaign(),
                        flight: campaign.toAdvisorFlight(),
                        pageOverride: 'Campaign Detail',
                      );
                  ref.read(globalAiAdvisorProvider.notifier).open();
                },
                icon: const Icon(Icons.eco_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.greenDeep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textFaint,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final String label;

  const _SourcePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.green.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.green.withAlpha(60)),
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
