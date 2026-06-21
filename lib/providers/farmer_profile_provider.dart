import 'package:flutter_riverpod/flutter_riverpod.dart';

class FarmerProfile {
  final String farmName;
  final String operatorName;
  final String cropType;
  final String fieldName;
  final String language;
  final String cropStage;
  final String notes;

  const FarmerProfile({
    required this.farmName,
    required this.operatorName,
    required this.cropType,
    required this.fieldName,
    required this.language,
    required this.cropStage,
    required this.notes,
  });

  factory FarmerProfile.initial() {
    return const FarmerProfile(
      farmName: '',
      operatorName: '',
      cropType: '',
      fieldName: '',
      language: 'en',
      cropStage: '',
      notes: '',
    );
  }

  FarmerProfile copyWith({
    String? farmName,
    String? operatorName,
    String? cropType,
    String? fieldName,
    String? language,
    String? cropStage,
    String? notes,
  }) {
    return FarmerProfile(
      farmName: farmName ?? this.farmName,
      operatorName: operatorName ?? this.operatorName,
      cropType: cropType ?? this.cropType,
      fieldName: fieldName ?? this.fieldName,
      language: language ?? this.language,
      cropStage: cropStage ?? this.cropStage,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toFieldContext() {
    return {
      if (fieldName.trim().isNotEmpty) 'field_name': fieldName.trim(),
      if (cropType.trim().isNotEmpty) 'crop_type': cropType.trim(),
      if (cropStage.trim().isNotEmpty) 'crop_stage': cropStage.trim(),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      'gps_available': false,
      'boundary_available': false,
    };
  }
}

class FarmerProfileNotifier extends Notifier<FarmerProfile> {
  @override
  FarmerProfile build() => FarmerProfile.initial();

  void update(FarmerProfile profile) {
    state = profile;
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }
}

final farmerProfileProvider =
    NotifierProvider<FarmerProfileNotifier, FarmerProfile>(
  FarmerProfileNotifier.new,
);
