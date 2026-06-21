import 'package:flutter_riverpod/flutter_riverpod.dart';

class DemoModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }

  void toggle() {
    state = !state;
  }
}

final demoModeProvider =
    NotifierProvider<DemoModeNotifier, bool>(DemoModeNotifier.new);

const demoPreviewLabel = 'Demo Preview — sample data only, not real farm data.';

class DemoDiagnosisSample {
  final String imageUrl;
  final String diseaseName;
  final double confidence;
  final String severity;
  final String cropType;
  final double moisturePct;
  final String locationLabel;
  final List<double> bbox;
  final String explanation;
  final String recommendation;
  final String reportTitle;

  const DemoDiagnosisSample({
    required this.imageUrl,
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.cropType,
    required this.moisturePct,
    required this.locationLabel,
    required this.bbox,
    required this.explanation,
    required this.recommendation,
    required this.reportTitle,
  });
}

const demoDiagnosisSample = DemoDiagnosisSample(
  imageUrl:
      'https://images.unsplash.com/photo-1530507629858-e4977d30e9e0?auto=format&fit=crop&w=1200&q=80',
  diseaseName: 'Brown Spot Disease',
  confidence: 0.78,
  severity: 'moderate',
  cropType: 'Rice',
  moisturePct: 42,
  locationLabel: 'East field, GPS-ready sample',
  bbox: [0.22, 0.18, 0.74, 0.70],
  explanation:
      'The crop image shows leaf spotting patterns consistent with Brown Spot. The AI confidence is useful for triage, but field inspection should confirm the result.',
  recommendation:
      'Check drainage and plant nutrition today, remove heavily affected leaves where practical, and retake a closer image if symptoms spread.',
  reportTitle: 'Rice Brown Spot Field Health Report',
);
