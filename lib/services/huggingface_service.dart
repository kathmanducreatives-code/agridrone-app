import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service interacting with the HuggingFace FastAPI YOLOv8 disease prediction model.
class HuggingFaceService {
  static const String _baseUrl = 'https://prasidhaaaa-aimodel.hf.space';
  static const String _apiSecret = 'agridrone2024';

  /// Verifies model server availability and configuration status.
  Future<Map<String, dynamic>> health() async {
    final response = await http.get(Uri.parse('$_baseUrl/health'));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HuggingFaceException('Health check failed: HTTP ${response.statusCode}');
  }

  /// Triggers disease analysis on a specific image index, writing results directly to Supabase.
  Future<Map<String, dynamic>> predict({
    required String imageUrl,
    required int flightCaptureId,
    required int flightId,
    required int imageIndex,
  }) async {
    debugPrint('[AgriDrone] Sending FastAPI prediction request for capture: $flightCaptureId');
    final response = await http.post(
      Uri.parse('$_baseUrl/predict'),
      headers: {
        'Authorization': 'Bearer $_apiSecret',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'image_url': imageUrl,
        'image_id': 'manual-${DateTime.now().millisecondsSinceEpoch}',
        'flight_capture_id': flightCaptureId,
        'flight_id': flightId,
        'image_index': imageIndex,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HuggingFaceException('FastAPI /predict failed with status ${response.statusCode}: ${response.body}');
  }

  /// Sends a test upload analysis prediction request to FastAPI, persisting detections in test tables.
  Future<Map<String, dynamic>> predictForTestUpload({
    required String imageUrl,
    required int testUploadId,
  }) async {
    debugPrint('[AgriDrone] Sending FastAPI prediction request for test upload: $testUploadId');
    final response = await http.post(
      Uri.parse('$_baseUrl/predict'),
      headers: {
        'Authorization': 'Bearer $_apiSecret',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'image_url': imageUrl,
        'image_id': 'test-$testUploadId',
        'test_upload_id': testUploadId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw HuggingFaceException('FastAPI /predict for test upload failed with status ${response.statusCode}: ${response.body}');
  }
}

/// Custom exception representing API integration failures.
class HuggingFaceException implements Exception {
  final String message;
  HuggingFaceException(this.message);

  @override
  String toString() => 'HuggingFaceException: $message';
}
