import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/dashboard_providers.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../providers/farmer_profile_provider.dart';
import '../providers/flight_providers.dart';
import '../theme/app_colors.dart';
import 'agri_ui.dart';

class GlobalAiAdvisorOverlay extends ConsumerWidget {
  final bool hasBottomNavigation;

  const GlobalAiAdvisorOverlay({
    super.key,
    required this.hasBottomNavigation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalAiAdvisorProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 760;
    final bottom = hasBottomNavigation ? 92.0 : 28.0;

    return Stack(
      children: [
        if (state.isOpen)
          if (isMobile)
            const Positioned.fill(
                child: GlobalAiAdvisorDrawer(fullScreen: true))
          else
            const Positioned(
              top: 24,
              right: 24,
              bottom: 24,
              width: 430,
              child: GlobalAiAdvisorDrawer(),
            ),
        Positioned(
          right: 24,
          bottom: state.isOpen && !isMobile ? 32 : bottom,
          child: const GlobalAiAdvisorBubble(),
        ),
      ],
    );
  }
}

class GlobalAiAdvisorBubble extends ConsumerWidget {
  const GlobalAiAdvisorBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalAiAdvisorProvider);
    return Tooltip(
      message: 'Ask AI Advisor',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => ref.read(globalAiAdvisorProvider.notifier).toggle(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: state.isOpen ? 14 : 18,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.green, AppColors.greenDeep],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.green.withAlpha(90),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  state.isOpen
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.eco_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                if (!state.isOpen) ...[
                  const SizedBox(width: 9),
                  Text(
                    'Ask AI Advisor',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlobalAiAdvisorDrawer extends ConsumerStatefulWidget {
  final bool fullScreen;

  const GlobalAiAdvisorDrawer({
    super.key,
    this.fullScreen = false,
  });

  @override
  ConsumerState<GlobalAiAdvisorDrawer> createState() =>
      _GlobalAiAdvisorDrawerState();
}

class _GlobalAiAdvisorDrawerState extends ConsumerState<GlobalAiAdvisorDrawer> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    final message = text.trim();
    if (message.isEmpty) return;
    _controller.clear();
    final contextPayload = ref.read(aiAdvisorAppContextProvider);
    final language = ref.read(farmerProfileProvider).language;
    ref
        .read(globalAiAdvisorProvider.notifier)
        .sendMessage(message, contextPayload, language: language)
        .then((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(globalAiAdvisorProvider);
    final appContext = ref.watch(aiAdvisorAppContextProvider);
    final currentPage = appContext['current_page']?.toString() ?? 'Farm Home';
    final prompts = [
      ...aiAdvisorPromptsForPage(currentPage),
      ...state.followUpQuestions,
    ].take(7).toList();

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(widget.fullScreen ? 0 : 30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(236),
            borderRadius: BorderRadius.circular(widget.fullScreen ? 0 : 30),
            border: Border.all(color: AppColors.green.withAlpha(55)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14532D).withAlpha(28),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                _AdvisorHeader(fullScreen: widget.fullScreen),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    children: [
                      AiContextCard(appContext: appContext),
                      const SizedBox(height: 14),
                      AiChatMessageList(messages: state.messages),
                      if (state.isLoading) ...[
                        const SizedBox(height: 10),
                        const _AdvisorLoading(),
                      ],
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        _AdvisorError(message: state.errorMessage!),
                      ],
                      if (state.suggestedActions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SuggestedActions(actions: state.suggestedActions),
                      ],
                      const SizedBox(height: 12),
                      AiPromptChips(
                        prompts: prompts,
                        onSelected: _send,
                      ),
                    ],
                  ),
                ),
                _AdvisorInput(
                  controller: _controller,
                  enabled: !state.isLoading,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.fullScreen) return content;
    return Material(color: Colors.transparent, child: content);
  }
}

class _AdvisorHeader extends ConsumerWidget {
  final bool fullScreen;

  const _AdvisorHeader({required this.fullScreen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.green.withAlpha(65)),
            ),
            child: const Icon(Icons.eco_rounded, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AgriDrone AI Advisor',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Ask about crop health, field actions, drone images, and reports.',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textDim,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: fullScreen ? 'Close AI Advisor' : 'Minimize AI Advisor',
            onPressed: () => ref.read(globalAiAdvisorProvider.notifier).close(),
            icon: Icon(
              fullScreen ? Icons.close_rounded : Icons.remove_rounded,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

class AiContextCard extends ConsumerWidget {
  final Map<String, dynamic> appContext;

  const AiContextCard({super.key, required this.appContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalAiAdvisorProvider);
    final page = appContext['current_page']?.toString() ?? 'Farm Home';
    final demoMode = appContext['demo_mode'] == true;
    final diagnosis = appContext['latest_diagnosis'];
    final field = appContext['field_context'];
    final weather = appContext['weather_context'];

    return AgriGlassCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContextRow(Icons.layers_rounded, 'Current page', page),
          if (state.selectedImageLabel != null)
            _ContextRow(
              Icons.image_rounded,
              'Selected image',
              state.selectedImageLabel!,
            ),
          if (diagnosis is Map)
            _ContextRow(
              Icons.health_and_safety_rounded,
              'Latest diagnosis',
              '${diagnosis['disease_name'] ?? 'Not available'} · ${diagnosis['severity'] ?? 'unknown'}',
            ),
          if (field is Map)
            _ContextRow(
              Icons.grass_rounded,
              'Crop and field',
              '${field['crop_type'] ?? 'Crop not selected'} · ${field['field_name'] ?? 'Field not selected'}',
            ),
          if (weather is Map)
            _ContextRow(
              Icons.wb_cloudy_outlined,
              'Local Weather',
              weather['source'] == 'not_configured'
                  ? 'Weather not connected'
                  : '${weather['temperature_c'] ?? '--'}°C',
            ),
          if (demoMode)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _DemoPreviewText(),
            ),
        ],
      ),
    );
  }
}

class _DemoPreviewText extends StatelessWidget {
  const _DemoPreviewText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Demo Preview — sample data only, not real farm data.',
      style: GoogleFonts.spaceGrotesk(
        color: AppColors.warn,
        fontSize: 11.5,
        height: 1.25,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContextRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AiChatMessageList extends StatelessWidget {
  final List<AiChatMessage> messages;

  const AiChatMessageList({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < messages.length; index++)
          Align(
            alignment: messages[index].fromUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: messages[index].fromUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 330),
                  margin: const EdgeInsets.only(bottom: 9),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: messages[index].fromUser
                        ? AppColors.green
                        : AppColors.green.withAlpha(16),
                    borderRadius: BorderRadius.circular(18),
                    border: messages[index].fromUser
                        ? null
                        : Border.all(color: AppColors.green.withAlpha(45)),
                  ),
                  child: messages[index].fromUser
                      ? Text(
                          messages[index].text,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : AdvisorMarkdown(
                          data: messages[index].text,
                          baseStyle: GoogleFonts.spaceGrotesk(
                            color: AppColors.text,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                if (!messages[index].fromUser && index > 0)
                  _MessageFeedback(messageIndex: index),
              ],
            ),
          ),
      ],
    );
  }
}

class _MessageFeedback extends ConsumerStatefulWidget {
  final int messageIndex;

  const _MessageFeedback({required this.messageIndex});

  @override
  ConsumerState<_MessageFeedback> createState() => _MessageFeedbackState();
}

class _MessageFeedbackState extends ConsumerState<_MessageFeedback> {
  String? _selected;

  Future<void> _send(String feedback) async {
    if (_selected != null) return;
    setState(() => _selected = feedback);
    try {
      await ref.read(aiAssistantServiceProvider).submitFeedback(
            targetType: 'chat_answer',
            targetId: 'session-message-${widget.messageIndex}',
            feedback: feedback,
            appContext: ref.read(aiAdvisorAppContextProvider),
          );
    } catch (_) {
      // Feedback should never block crop guidance.
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = const [
      ('Helpful', 'helpful', Icons.thumb_up_alt_outlined),
      ('Not helpful', 'not_helpful', Icons.thumb_down_alt_outlined),
      (
        'Needs expert review',
        'needs_expert_review',
        Icons.person_search_rounded
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in options)
            ActionChip(
              onPressed: _selected == null ? () => _send(option.$2) : null,
              avatar: Icon(option.$3, size: 14),
              label: Text(_selected == option.$2 ? 'Sent' : option.$1),
              labelStyle: GoogleFonts.spaceGrotesk(
                color: AppColors.textDim,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
              visualDensity: VisualDensity.compact,
              side: const BorderSide(color: AppColors.line),
              backgroundColor: Colors.white.withAlpha(210),
            ),
        ],
      ),
    );
  }
}

class AiPromptChips extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onSelected;

  const AiPromptChips({
    super.key,
    required this.prompts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: prompts
          .map(
            (prompt) => ActionChip(
              onPressed: () => onSelected(prompt),
              avatar: const Icon(Icons.auto_awesome_rounded, size: 15),
              label: Text(prompt),
              labelStyle: GoogleFonts.spaceGrotesk(
                color: AppColors.greenDeep,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(color: AppColors.green.withAlpha(55)),
              backgroundColor: Colors.white.withAlpha(210),
            ),
          )
          .toList(),
    );
  }
}

class _SuggestedActions extends ConsumerWidget {
  final List<dynamic> actions;

  const _SuggestedActions({required this.actions});

  /// Maps an AI action code (or its label) to a destination tab index.
  /// Nav order: 0 Farm Home, 1 AI Advisor, 2 Campaigns, 3 Crop Images,
  /// 4 Drone Activity, 5 Field Map, 6 Reports, 7 Action Plan, 8 Settings.
  int? _tabFor(String action, String label) {
    final a = '$action $label'.toLowerCase();
    if (a.contains('report')) {
      return a.contains('generate') || a.contains('create') ? 2 : 6;
    }
    if (a.contains('add_image') || a.contains('add image') ||
        a.contains('create_campaign') || a.contains('campaign')) {
      return 2;
    }
    if (a.contains('analyze') ||
        a.contains('crop_image') ||
        a.contains('crop image') ||
        a.contains('review') ||
        a.contains('image')) {
      return 3;
    }
    if (a.contains('map') || a.contains('gps') || a.contains('boundary') ||
        a.contains('field')) {
      return 5;
    }
    if (a.contains('drone') || a.contains('flight') || a.contains('checklist')) {
      return 4;
    }
    if (a.contains('action') || a.contains('task') || a.contains('plan')) {
      return 7;
    }
    if (a.contains('weather') || a.contains('setting') ||
        a.contains('profile') || a.contains('connect')) {
      return 8;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((action) {
        final label = action.label?.toString() ?? '';
        final code = action.action?.toString() ?? '';
        final tab = _tabFor(code, label);
        return ActionChip(
          avatar: Icon(
            tab == null ? Icons.task_alt_rounded : Icons.arrow_forward_rounded,
            size: 15,
            color: AppColors.greenDeep,
          ),
          label: Text(label),
          labelStyle: GoogleFonts.spaceGrotesk(
            color: AppColors.greenDeep,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
          side: BorderSide(color: AppColors.green.withAlpha(60)),
          backgroundColor: AppColors.green.withAlpha(16),
          onPressed: tab == null
              ? null
              : () {
                  ref.read(currentTabProvider.notifier).set(tab);
                  ref.read(globalAiAdvisorProvider.notifier).close();
                },
        );
      }).toList(),
    );
  }
}

class _AdvisorLoading extends StatelessWidget {
  const _AdvisorLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.teal.withAlpha(16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.teal.withAlpha(55)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              color: AppColors.teal,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'AI Advisor is preparing guidance...',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisorError extends StatelessWidget {
  final String message;

  const _AdvisorError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warn.withAlpha(16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warn.withAlpha(55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.warn, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.text,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight Markdown renderer for AI Advisor answers.
///
/// The AI returns simple Markdown (bold, headings, bullet and numbered lists,
/// emoji). Flutter's plain [Text] would show raw `**` and `#` characters, so
/// this renders the common cases without pulling in a Markdown package. It only
/// handles `**bold**` / `__bold__` inline to avoid mangling words that contain
/// single `*` or `_` (e.g. units like `5 m/s`).
class AdvisorMarkdown extends StatelessWidget {
  final String data;
  final TextStyle baseStyle;

  const AdvisorMarkdown({
    super.key,
    required this.data,
    required this.baseStyle,
  });

  static final RegExp _bold = RegExp(r'(\*\*|__)(.+?)\1');
  static final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^\s*[-*+]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final RegExp _rule = RegExp(r'^\s*([-*_])\1{2,}\s*$');
  static final RegExp _tableRow = RegExp(r'^\s*\|(.+)\|\s*$');
  static final RegExp _blockquote = RegExp(r'^\s*>\s?(.*)$');

  TextSpan _inline(String text, TextStyle style) {
    // Collapse bold-italic (`***`/`___`) to bold so no stray markers remain,
    // and drop inline code backticks.
    final clean = text
        .replaceAll('`', '')
        .replaceAll('***', '**')
        .replaceAll('___', '__');
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _bold.allMatches(clean)) {
      if (m.start > last) {
        spans.add(TextSpan(text: clean.substring(last, m.start), style: style));
      }
      spans.add(TextSpan(
        text: m.group(2),
        style: style.copyWith(fontWeight: FontWeight.w900),
      ));
      last = m.end;
    }
    if (last < clean.length) {
      spans.add(TextSpan(text: clean.substring(last), style: style));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: clean, style: style));
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final lines = data.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 6));
        continue;
      }
      if (_rule.hasMatch(line)) {
        blocks.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, color: AppColors.line),
        ));
        continue;
      }
      final h = _heading.firstMatch(line);
      if (h != null) {
        final level = h.group(1)!.length;
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: RichText(
            text: _inline(
              h.group(2)!,
              baseStyle.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: (baseStyle.fontSize ?? 13) + (level <= 2 ? 2 : 1),
              ),
            ),
          ),
        ));
        continue;
      }
      final tr = _tableRow.firstMatch(line);
      if (tr != null) {
        final cells = tr
            .group(1)!
            .split('|')
            .map((c) => c.trim())
            .toList();
        // Skip separator rows like |---|:--:|
        final isSeparator = cells.every(
            (c) => c.isEmpty || RegExp(r'^:?-{1,}:?$').hasMatch(c));
        if (isSeparator) continue;
        final nonEmpty = cells.where((c) => c.isNotEmpty).toList();
        if (nonEmpty.length == 2) {
          // Render key/value rows as "Key — value".
          blocks.add(Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 1),
            child: RichText(
              text: TextSpan(children: [
                _inline(nonEmpty[0],
                    baseStyle.copyWith(fontWeight: FontWeight.w900)),
                TextSpan(text: '  —  ', style: baseStyle),
                _inline(nonEmpty[1], baseStyle),
              ]),
            ),
          ));
        } else {
          blocks.add(Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 1),
            child: RichText(text: _inline(nonEmpty.join('   ·   '), baseStyle)),
          ));
        }
        continue;
      }
      final bq = _blockquote.firstMatch(line);
      if (bq != null) {
        blocks.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          decoration: const BoxDecoration(
            border: Border(
                left: BorderSide(color: AppColors.green, width: 3)),
          ),
          child: RichText(text: _inline(bq.group(1) ?? '', baseStyle)),
        ));
        continue;
      }
      final b = _bullet.firstMatch(line);
      if (b != null) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 1, bottom: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: baseStyle),
              Expanded(child: RichText(text: _inline(b.group(1)!, baseStyle))),
            ],
          ),
        ));
        continue;
      }
      final n = _numbered.firstMatch(line);
      if (n != null) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 1, bottom: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${n.group(1)}.  ',
                  style: baseStyle.copyWith(fontWeight: FontWeight.w800)),
              Expanded(child: RichText(text: _inline(n.group(2)!, baseStyle))),
            ],
          ),
        ));
        continue;
      }
      blocks.add(RichText(text: _inline(line, baseStyle)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}

class _AdvisorInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;

  const _AdvisorInput({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? onSend : null,
              decoration: InputDecoration(
                hintText: 'Ask what to do next...',
                hintStyle: GoogleFonts.spaceGrotesk(
                  color: AppColors.textFaint,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.green),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: enabled ? () => onSend(controller.text) : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.textFaint.withAlpha(50),
            ),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
