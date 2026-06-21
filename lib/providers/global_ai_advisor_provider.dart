import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_assistant.dart';
import 'dashboard_providers.dart';
import 'demo_mode_provider.dart';
import 'farmer_profile_provider.dart';
import 'flight_providers.dart';

// Order must match AgriAppShell._items and MainNavigationScreen.screens.
const aiAdvisorPageLabels = [
  'Farm Home',
  'AI Advisor',
  'Campaigns',
  'Crop Images',
  'Drone Activity',
  'Field Map',
  'Reports',
  'Action Plan',
  'Settings',
];

class AiChatMessage {
  final bool fromUser;
  final String text;
  final DateTime createdAt;

  const AiChatMessage({
    required this.fromUser,
    required this.text,
    required this.createdAt,
  });
}

class GlobalAiAdvisorState {
  final bool isOpen;
  final bool isLoading;
  final String? errorMessage;
  final List<AiChatMessage> messages;
  final List<AiSuggestedAction> suggestedActions;
  final List<String> followUpQuestions;
  final AiDetectionContext? selectedDiagnosis;
  final String? selectedImageUrl;
  final String? selectedImageLabel;
  final String? pageOverride;
  final Map<String, dynamic>? selectedCampaign;
  final Map<String, dynamic>? selectedFlight;

  const GlobalAiAdvisorState({
    required this.isOpen,
    required this.isLoading,
    required this.messages,
    required this.suggestedActions,
    required this.followUpQuestions,
    this.errorMessage,
    this.selectedDiagnosis,
    this.selectedImageUrl,
    this.selectedImageLabel,
    this.pageOverride,
    this.selectedCampaign,
    this.selectedFlight,
  });

  factory GlobalAiAdvisorState.initial() {
    return GlobalAiAdvisorState(
      isOpen: false,
      isLoading: false,
      messages: [
        AiChatMessage(
          fromUser: false,
          text:
              'Hi, I’m your AgriDrone AI Advisor. Ask me what to do today, how serious a crop issue is, or how to prepare a farmer report.',
          createdAt: DateTime.now(),
        ),
      ],
      suggestedActions: const [],
      followUpQuestions: const [],
    );
  }

  GlobalAiAdvisorState copyWith({
    bool? isOpen,
    bool? isLoading,
    Object? errorMessage = _sentinel,
    List<AiChatMessage>? messages,
    List<AiSuggestedAction>? suggestedActions,
    List<String>? followUpQuestions,
    Object? selectedDiagnosis = _sentinel,
    Object? selectedImageUrl = _sentinel,
    Object? selectedImageLabel = _sentinel,
    Object? pageOverride = _sentinel,
    Object? selectedCampaign = _sentinel,
    Object? selectedFlight = _sentinel,
  }) {
    return GlobalAiAdvisorState(
      isOpen: isOpen ?? this.isOpen,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      messages: messages ?? this.messages,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      followUpQuestions: followUpQuestions ?? this.followUpQuestions,
      selectedDiagnosis: selectedDiagnosis == _sentinel
          ? this.selectedDiagnosis
          : selectedDiagnosis as AiDetectionContext?,
      selectedImageUrl: selectedImageUrl == _sentinel
          ? this.selectedImageUrl
          : selectedImageUrl as String?,
      selectedImageLabel: selectedImageLabel == _sentinel
          ? this.selectedImageLabel
          : selectedImageLabel as String?,
      pageOverride: pageOverride == _sentinel
          ? this.pageOverride
          : pageOverride as String?,
      selectedCampaign: selectedCampaign == _sentinel
          ? this.selectedCampaign
          : selectedCampaign as Map<String, dynamic>?,
      selectedFlight: selectedFlight == _sentinel
          ? this.selectedFlight
          : selectedFlight as Map<String, dynamic>?,
    );
  }
}

const _sentinel = Object();

final globalAiAdvisorProvider =
    NotifierProvider<GlobalAiAdvisorNotifier, GlobalAiAdvisorState>(
  GlobalAiAdvisorNotifier.new,
);

class GlobalAiAdvisorNotifier extends Notifier<GlobalAiAdvisorState> {
  @override
  GlobalAiAdvisorState build() => GlobalAiAdvisorState.initial();

  void open({String? prompt}) {
    state = state.copyWith(isOpen: true, errorMessage: null);
    if (prompt != null && prompt.trim().isNotEmpty) {
      addUserDraft(prompt);
    }
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }

  void toggle() {
    state = state.copyWith(isOpen: !state.isOpen, errorMessage: null);
  }

  void setSelectedDiagnosis({
    required AiDetectionContext context,
    String? imageUrl,
    String? imageLabel,
    String? pageOverride,
  }) {
    state = state.copyWith(
      selectedDiagnosis: context,
      selectedImageUrl: imageUrl,
      selectedImageLabel: imageLabel,
      pageOverride: pageOverride,
    );
  }

  void clearSelectedDiagnosis() {
    state = state.copyWith(
      selectedDiagnosis: null,
      selectedImageUrl: null,
      selectedImageLabel: null,
      pageOverride: null,
    );
  }

  void clearPageOverride() {
    state = state.copyWith(pageOverride: null);
  }

  /// Scope the advisor to a specific campaign (and optionally its flight).
  void setCampaignContext({
    required Map<String, dynamic> campaign,
    Map<String, dynamic>? flight,
    String pageOverride = 'Campaign Detail',
  }) {
    state = state.copyWith(
      selectedCampaign: campaign,
      selectedFlight: flight,
      pageOverride: pageOverride,
    );
  }

  void clearCampaignContext() {
    state = state.copyWith(
      selectedCampaign: null,
      selectedFlight: null,
      pageOverride: null,
    );
  }

  void addUserDraft(String prompt) {
    final text = prompt.trim();
    if (text.isEmpty) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        AiChatMessage(fromUser: true, text: text, createdAt: DateTime.now()),
      ],
    );
  }

  Future<void> sendMessage(
    String message,
    Map<String, dynamic> appContext, {
    String language = 'en',
  }) async {
    final text = message.trim();
    if (text.isEmpty || state.isLoading) return;

    state = state.copyWith(
      isOpen: true,
      isLoading: true,
      errorMessage: null,
      messages: [
        ...state.messages,
        AiChatMessage(fromUser: true, text: text, createdAt: DateTime.now()),
      ],
    );

    try {
      final response = await ref.read(aiAssistantServiceProvider).chat(
            message: text,
            appContext: appContext,
            language: language,
          );
      state = state.copyWith(
        isLoading: false,
        suggestedActions: response.suggestedActions,
        followUpQuestions: response.followUpQuestions,
        messages: [
          ...state.messages,
          AiChatMessage(
            fromUser: false,
            text: response.answer,
            createdAt: DateTime.now(),
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final aiAdvisorAppContextProvider = Provider<Map<String, dynamic>>((ref) {
  final tab = ref.watch(currentTabProvider);
  final demoMode = ref.watch(demoModeProvider);
  final profile = ref.watch(farmerProfileProvider);
  final advisorState = ref.watch(globalAiAdvisorProvider);
  final currentPage = advisorState.pageOverride ??
      (tab >= 0 && tab < aiAdvisorPageLabels.length
          ? aiAdvisorPageLabels[tab]
          : 'Farm Home');

  final selected = advisorState.selectedDiagnosis;
  final fieldContext = profile.toFieldContext();
  final cropType = selected?.cropType ?? profile.cropType;
  if (cropType.trim().isNotEmpty) {
    fieldContext['crop_type'] = cropType.trim();
  }
  if (selected?.moisturePct != null) {
    fieldContext['moisture_pct'] = selected!.moisturePct;
  }

  final context = <String, dynamic>{
    'current_page': currentPage,
    'user_mode': 'farmer',
    'demo_mode': demoMode,
    if (demoMode) 'demo_label': demoPreviewLabel,
    if (profile.farmName.trim().isNotEmpty)
      'farm_name': profile.farmName.trim(),
    if (profile.operatorName.trim().isNotEmpty)
      'operator_name': profile.operatorName.trim(),
    'field_context': fieldContext,
    'flight_context': {
      'flight_status': 'not_started',
      'direct_control_connected': false,
      'flight_path_available': false,
      'latest_images_count': 0,
    },
    'weather_context': {
      'temperature_c': null,
      'condition': null,
      'humidity': null,
      'source': 'not_configured',
    },
    'soil_moisture_context': {
      'available': selected?.moisturePct != null,
      'moisture_pct': selected?.moisturePct,
    },
    'report_context': {
      'latest_report_available': false,
    },
    if (advisorState.selectedCampaign != null)
      'selected_campaign': advisorState.selectedCampaign,
    if (advisorState.selectedFlight != null)
      'selected_flight': advisorState.selectedFlight,
  };

  if (selected != null) {
    context['selected_capture'] = {
      if (selected.captureId != null) 'id': selected.captureId,
      if (advisorState.selectedImageUrl != null)
        'image_url': advisorState.selectedImageUrl,
      'quality_status': 'good',
    };
    context['latest_diagnosis'] = {
      'disease_name': selected.diseaseName,
      'confidence': selected.confidence,
      'severity': selected.severity,
      'crop_type': selected.cropType,
    };
  }

  return _removeNulls(context);
});

Map<String, dynamic> _removeNulls(Map<String, dynamic> value) {
  final cleaned = <String, dynamic>{};
  for (final entry in value.entries) {
    final item = entry.value;
    if (item == null) continue;
    if (item is Map<String, dynamic>) {
      cleaned[entry.key] = _removeNulls(item);
    } else {
      cleaned[entry.key] = item;
    }
  }
  return cleaned;
}

List<String> aiAdvisorPromptsForPage(String page) {
  switch (page) {
    case 'Farm Home':
      return const [
        'What should I do today?',
        'Explain my crop health score',
        'Show urgent crop actions',
        'Create a farmer summary',
        'What changed since the last check?',
      ];
    case 'Campaigns':
      return const [
        'Which campaign needs attention?',
        'Help me create a campaign',
        'What data is missing?',
        'What is a crop campaign?',
        'Summarize my campaigns',
      ];
    case 'Campaign Detail':
      return const [
        'Summarize this campaign',
        'Which image needs attention?',
        'Generate a campaign report',
        'What should I do today?',
        'What data is missing from this campaign?',
      ];
    case 'Check Crop':
      return const [
        'How do I take a good crop image?',
        'Should I retake this image?',
        'What happens after I upload?',
        'Explain the latest diagnosis',
        'Get treatment advice',
      ];
    case 'Crop Images':
      return const [
        'Which images need review?',
        'Which images show disease?',
        'Why was this image low confidence?',
        'Summarize all checked images',
        'Help me choose an image for report',
      ];
    case 'Diagnosis':
      return const [
        'Explain this disease',
        'How serious is this?',
        'What should I do today?',
        'Give organic treatment options',
        'Generate a farmer report',
        'What should I ask an agriculture expert?',
      ];
    case 'Field Map':
      return const [
        'Which field area needs attention?',
        'What does this field marker mean?',
        'Is disease spreading?',
        'Where should I inspect first?',
        'Explain field risk level',
      ];
    case 'Drone Activity':
      return const [
        'How do I start a drone flight?',
        'What should I check before flying?',
        'How does drone capture help crop health?',
        'What should I do after landing?',
        'Why are no new images showing?',
      ];
    case 'Action Plan':
      return const [
        'What is the highest priority task?',
        'What should I do today?',
        'Why is this action recommended?',
        'Create a checklist for the field',
        'Mark this as ready for report',
      ];
    case 'Reports':
      return const [
        'Create a crop health report',
        'Summarize this report',
        'Make this report judge-friendly',
        'Explain this report in simple farmer language',
        'What should be included in the report?',
      ];
    case 'Settings':
      return const [
        'Help me choose crop type',
        'What does demo mode do?',
        'Help me fill required fields',
        'Explain farm preferences',
        'Check if the app is ready for demo',
      ];
    default:
      return const [
        'What should I do today?',
        'Explain the latest crop result',
        'Create a crop health report',
      ];
  }
}
