class AiDetectionContext {
  final String? captureId;
  final String? detectionId;
  final String? flightId;
  final String diseaseName;
  final double confidence;
  final String severity;
  final String cropType;
  final double? moisturePct;
  final List<double>? bbox;

  const AiDetectionContext({
    this.captureId,
    this.detectionId,
    this.flightId,
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    this.cropType = 'rice',
    this.moisturePct,
    this.bbox,
  });

  Map<String, dynamic> toRequestPayload({
    String language = 'en',
    String farmerLevel = 'simple',
  }) {
    return {
      if (captureId != null) 'capture_id': captureId,
      if (detectionId != null) 'detection_id': detectionId,
      if (flightId != null) 'flight_id': flightId,
      'language': language,
      'farmer_level': farmerLevel,
      'detection_context': {
        'disease_name': diseaseName,
        'confidence': confidence,
        'severity': severity,
        'crop_type': cropType,
        if (moisturePct != null) 'moisture_pct': moisturePct,
        if (bbox != null) 'bbox': bbox,
      },
    };
  }
}

class AiExplanation {
  final String diseaseName;
  final double confidence;
  final String severity;
  final String summary;
  final String farmerFriendlyExplanation;
  final List<String> likelyCauses;
  final List<String> immediateActions;
  final List<String> organicTreatment;
  final List<String> chemicalTreatment;
  final List<String> preventionTips;
  final String confidenceDisclaimer;
  final String expertEscalation;
  final bool saved;
  final String? explanationId;
  final String provider;
  final String model;
  final String contextSource;

  const AiExplanation({
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.summary,
    required this.farmerFriendlyExplanation,
    required this.likelyCauses,
    required this.immediateActions,
    required this.organicTreatment,
    required this.chemicalTreatment,
    required this.preventionTips,
    required this.confidenceDisclaimer,
    required this.expertEscalation,
    required this.saved,
    this.explanationId,
    required this.provider,
    required this.model,
    required this.contextSource,
  });

  factory AiExplanation.fromJson(Map<String, dynamic> json) {
    final body = _map(json['explanation']);
    return AiExplanation(
      diseaseName: _string(body['disease_name'], fallback: 'Unknown disease'),
      confidence: _double(body['confidence']),
      severity: _string(body['severity'], fallback: 'unknown'),
      summary: _string(body['summary']),
      farmerFriendlyExplanation: _string(body['farmer_friendly_explanation']),
      likelyCauses: _stringList(body['likely_causes']),
      immediateActions: _stringList(body['immediate_actions']),
      organicTreatment: _stringList(body['organic_treatment']),
      chemicalTreatment: _stringList(body['chemical_treatment']),
      preventionTips: _stringList(body['prevention_tips']),
      confidenceDisclaimer: _string(body['confidence_disclaimer']),
      expertEscalation: _string(body['expert_escalation']),
      saved: json['saved'] == true,
      explanationId: json['explanation_id']?.toString(),
      provider: _string(json['provider'], fallback: 'anthropic'),
      model: _string(json['model']),
      contextSource:
          _string(json['context_source'], fallback: 'request_fallback'),
    );
  }
}

class AiRecommendation {
  final String recommendedNextStep;
  final String urgency;
  final List<String> organicOptions;
  final List<String> chemicalOptions;
  final List<String> prevention;
  final String whenToCallExpert;
  final String provider;
  final String model;
  final String contextSource;

  const AiRecommendation({
    required this.recommendedNextStep,
    required this.urgency,
    required this.organicOptions,
    required this.chemicalOptions,
    required this.prevention,
    required this.whenToCallExpert,
    required this.provider,
    required this.model,
    required this.contextSource,
  });

  factory AiRecommendation.fromJson(Map<String, dynamic> json) {
    return AiRecommendation(
      recommendedNextStep: _string(json['recommended_next_step']),
      urgency: _string(json['urgency'], fallback: 'medium'),
      organicOptions: _stringList(json['organic_options']),
      chemicalOptions: _stringList(json['chemical_options']),
      prevention: _stringList(json['prevention']),
      whenToCallExpert: _string(json['when_to_call_expert']),
      provider: _string(json['provider'], fallback: 'anthropic'),
      model: _string(json['model']),
      contextSource:
          _string(json['context_source'], fallback: 'request_fallback'),
    );
  }
}

class AiReport {
  final String title;
  final String reportMarkdown;
  final Map<String, dynamic> reportJson;
  final bool saved;
  final String? reportId;
  final String provider;
  final String model;
  final String contextSource;

  const AiReport({
    required this.title,
    required this.reportMarkdown,
    required this.reportJson,
    required this.saved,
    this.reportId,
    required this.provider,
    required this.model,
    required this.contextSource,
  });

  factory AiReport.fromJson(Map<String, dynamic> json) {
    return AiReport(
      title: _string(json['title'], fallback: 'Crop Health Report'),
      reportMarkdown: _string(json['report_markdown']),
      reportJson: _map(json['report_json']),
      saved: json['saved'] == true,
      reportId: json['report_id']?.toString(),
      provider: _string(json['provider'], fallback: 'anthropic'),
      model: _string(json['model']),
      contextSource:
          _string(json['context_source'], fallback: 'request_fallback'),
    );
  }
}

class AiJudgeSummary {
  final String oneLiner;
  final String whatHappened;
  final String whyItMatters;
  final String whatFarmerShouldDo;
  final String technicalPipeline;
  final String provider;
  final String model;
  final String contextSource;

  const AiJudgeSummary({
    required this.oneLiner,
    required this.whatHappened,
    required this.whyItMatters,
    required this.whatFarmerShouldDo,
    required this.technicalPipeline,
    required this.provider,
    required this.model,
    required this.contextSource,
  });

  factory AiJudgeSummary.fromJson(Map<String, dynamic> json) {
    return AiJudgeSummary(
      oneLiner: _string(json['one_liner']),
      whatHappened: _string(json['what_happened']),
      whyItMatters: _string(json['why_it_matters']),
      whatFarmerShouldDo: _string(json['what_farmer_should_do']),
      technicalPipeline: _string(json['technical_pipeline']),
      provider: _string(json['provider'], fallback: 'anthropic'),
      model: _string(json['model']),
      contextSource:
          _string(json['context_source'], fallback: 'request_fallback'),
    );
  }
}

class AiSuggestedAction {
  final String label;
  final String action;

  const AiSuggestedAction({
    required this.label,
    required this.action,
  });

  factory AiSuggestedAction.fromJson(Map<String, dynamic> json) {
    return AiSuggestedAction(
      label: _string(json['label']),
      action: _string(json['action']),
    );
  }
}

class AiChatResponse {
  final String answer;
  final List<AiSuggestedAction> suggestedActions;
  final List<String> followUpQuestions;
  final List<String> contextUsed;

  const AiChatResponse({
    required this.answer,
    required this.suggestedActions,
    required this.followUpQuestions,
    required this.contextUsed,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      answer: _string(json['answer']),
      suggestedActions: _mapList(json['suggested_actions'])
          .map(AiSuggestedAction.fromJson)
          .toList(),
      followUpQuestions: _stringList(json['follow_up_questions']),
      contextUsed: _stringList(json['context_used']),
    );
  }
}

class AiFeedbackResponse {
  final bool ok;
  final bool saved;

  const AiFeedbackResponse({
    required this.ok,
    required this.saved,
  });

  factory AiFeedbackResponse.fromJson(Map<String, dynamic> json) {
    return AiFeedbackResponse(
      ok: json['ok'] == true,
      saved: json['saved'] == true,
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return {};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is List) {
    return value.map(_map).where((item) => item.isNotEmpty).toList();
  }
  return const [];
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  return const [];
}
