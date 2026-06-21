import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';

/// Service interacting with the HuggingFace FastAPI YOLOv8 disease prediction model.
class HuggingFaceService {
  static const Duration _healthTimeout = Duration(seconds: 12);
  static const Duration _predictTimeout = Duration(seconds: 60);

  /// Verifies model server availability and configuration status.
  Future<Map<String, dynamic>> health() async {
    try {
      final response = await http
          .get(Uri.parse(SupabaseConfig.huggingFaceHealthUrl))
          .timeout(_healthTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw HuggingFaceException(
        'Image Analysis connection check failed with HTTP ${response.statusCode}.',
        code: 'backend_health_failed',
      );
    } on TimeoutException {
      throw HuggingFaceException(
        'Image Analysis is getting ready. Please retry after a few seconds.',
        code: 'backend_timeout',
      );
    }
  }

  /// Triggers disease analysis on a specific image index, writing results directly to Supabase.
  Future<Map<String, dynamic>> predict({
    required String imageUrl,
    required int flightCaptureId,
    required int flightId,
    required int imageIndex,
  }) async {
    final imageUrlError = _validateImageUrl(imageUrl);
    if (imageUrlError != null) {
      throw HuggingFaceException(imageUrlError, code: 'invalid_image_url');
    }

    debugPrint(
        '[AgriDrone] Sending FastAPI prediction request for capture: $flightCaptureId');
    final response = await _postPredict({
      'image_url': imageUrl,
      'image_id': 'manual-${DateTime.now().millisecondsSinceEpoch}',
      'flight_capture_id': flightCaptureId,
      'flight_id': flightId,
      'image_index': imageIndex,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _exceptionFromResponse(response,
        fallbackContext: 'Image Analysis failed');
  }

  /// Sends a test upload analysis prediction request to FastAPI, persisting detections in test tables.
  Future<Map<String, dynamic>> predictForTestUpload({
    required String imageUrl,
    required int testUploadId,
  }) async {
    final imageUrlError = _validateImageUrl(imageUrl);
    if (imageUrlError != null) {
      throw HuggingFaceException(imageUrlError, code: 'invalid_image_url');
    }

    debugPrint(
        '[AgriDrone] Sending FastAPI prediction request for test upload: $testUploadId');
    final response = await _postPredict({
      'image_url': imageUrl,
      'image_id': 'test-$testUploadId',
      'test_upload_id': testUploadId,
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _exceptionFromResponse(response,
        fallbackContext: 'Image Analysis failed for this crop image');
  }

  Future<http.Response> _postPredict(Map<String, dynamic> payload) async {
    try {
      return await http
          .post(
            Uri.parse(SupabaseConfig.huggingFacePredictUrl),
            headers: {
              'Authorization': 'Bearer ${SupabaseConfig.huggingFaceToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_predictTimeout);
    } on TimeoutException {
      throw HuggingFaceException(
        'Image Analysis took too long. Retry, or use an already checked demo image.',
        code: 'model_timeout',
      );
    } catch (e) {
      throw HuggingFaceException(
        'Image Analysis request failed. Please check the connection and try again.',
        code: 'backend_offline',
      );
    }
  }

  HuggingFaceException _exceptionFromResponse(
    http.Response response, {
    required String fallbackContext,
  }) {
    String message = '$fallbackContext with HTTP ${response.statusCode}.';
    String code = 'backend_error';
    try {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      final error = detail is Map<String, dynamic> ? detail['error'] : null;
      if (error is Map<String, dynamic>) {
        code = error['code']?.toString() ?? code;
        message = error['message']?.toString() ?? message;
      } else if (detail is String) {
        message = detail;
      }
    } catch (_) {
      // Keep the safe fallback message.
    }
    return HuggingFaceException(message,
        code: code, statusCode: response.statusCode);
  }

  String? _validateImageUrl(String imageUrl) {
    final uri = Uri.tryParse(imageUrl.trim());
    if (uri == null || imageUrl.trim().isEmpty) {
      return 'Missing crop image link. Wait for the image to finish syncing.';
    }
    if (!uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return 'Invalid crop image link. Select another image or upload a clearer crop photo.';
    }
    return null;
  }
}

/// Custom exception representing API integration failures.
class HuggingFaceException implements Exception {
  final String message;
  final String code;
  final int? statusCode;

  HuggingFaceException(
    this.message, {
    this.code = 'unknown',
    this.statusCode,
  });

  @override
  String toString() => message;
}
