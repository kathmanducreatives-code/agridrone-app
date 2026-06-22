import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';
import '../models/ai_assistant.dart';

class AiAssistantService {
  static const Duration _healthTimeout = Duration(seconds: 12);
  static const Duration _aiTimeout = Duration(seconds: 90);

  Future<Map<String, dynamic>> health() async {
    try {
      final response = await http
          .get(Uri.parse(SupabaseConfig.aiAssistantHealthUrl))
          .timeout(_healthTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _decodeMap(response.body);
      }
      throw AiAssistantException(
        'AI Advisor connection check failed with HTTP ${response.statusCode}.',
        code: 'backend_health_failed',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw AiAssistantException(
        'AI Advisor is getting ready. Please retry after a few seconds.',
        code: 'backend_timeout',
      );
    } on AiAssistantException {
      rethrow;
    } catch (_) {
      throw AiAssistantException(
        'AI Advisor needs connection. Please ask the demo operator to reconnect it.',
        code: 'backend_offline',
      );
    }
  }

  Future<AiExplanation> explain(AiDetectionContext context) async {
    final json = await _postJson(
        SupabaseConfig.aiExplainAnalysisUrl, context.toRequestPayload());
    return AiExplanation.fromJson(json);
  }

  Future<AiRecommendation> recommend(AiDetectionContext context) async {
    final json = await _postJson(
        SupabaseConfig.aiRecommendationUrl, context.toRequestPayload());
    return AiRecommendation.fromJson(json);
  }

  Future<AiReport> report(AiDetectionContext context) async {
    final json =
        await _postJson(SupabaseConfig.aiReportUrl, context.toRequestPayload());
    return AiReport.fromJson(json);
  }

  Future<AiJudgeSummary> judgeSummary(AiDetectionContext context) async {
    final json = await _postJson(
        SupabaseConfig.aiJudgeSummaryUrl, context.toRequestPayload());
    return AiJudgeSummary.fromJson(json);
  }

  Future<AiChatResponse> chat({
    required String message,
    required Map<String, dynamic> appContext,
    String language = 'en',
  }) async {
    final json = await _postJson(SupabaseConfig.aiChatUrl, {
      'message': message,
      'language': language,
      'app_context': appContext,
    });
    return AiChatResponse.fromJson(json);
  }

  Future<AiFeedbackResponse> submitFeedback({
    required String targetType,
    String? targetId,
    required String feedback,
    String? notes,
    Map<String, dynamic>? appContext,
  }) async {
    final json = await _postJson(SupabaseConfig.aiFeedbackUrl, {
      'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      'feedback': feedback,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (appContext != null) 'app_context': appContext,
    });
    return AiFeedbackResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> _postJson(
      String url, Map<String, dynamic> payload) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer ${SupabaseConfig.huggingFaceToken}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_aiTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _decodeMap(response.body);
      }
      throw _exceptionFromResponse(response);
    } on TimeoutException {
      throw AiAssistantException(
        'AI Advisor took too long to respond. Please try again, or use the saved crop result for the demo.',
        code: 'anthropic_timeout',
      );
    } on AiAssistantException {
      rethrow;
    } catch (_) {
      throw AiAssistantException(
        'AI Advisor request failed. Please check the connection and try again.',
        code: 'backend_offline',
      );
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw AiAssistantException(
      'AI Advisor returned an unreadable response.',
      code: 'malformed_ai_response',
    );
  }

  AiAssistantException _exceptionFromResponse(http.Response response) {
    String code = 'backend_error';
    String message = 'AI request failed with HTTP ${response.statusCode}.';
    try {
      final decoded = _decodeMap(response.body);
      final detail = decoded['detail'];
      final error = detail is Map<String, dynamic> ? detail['error'] : null;
      if (error is Map<String, dynamic>) {
        code = error['code']?.toString() ?? code;
        message =
            _friendlyMessage(code, error['message']?.toString() ?? message);
      } else if (detail is String) {
        message = detail;
      }
    } catch (_) {
      // Keep fallback message.
    }
    return AiAssistantException(message,
        code: code, statusCode: response.statusCode);
  }

  String _friendlyMessage(String code, String fallback) {
    switch (code) {
      case 'anthropic_not_configured':
      case 'anthropic_model_missing':
        return 'AI Advisor is not ready yet. Please check Advanced Settings or ask the demo operator to reconnect it.';
      case 'anthropic_timeout':
        return 'AI Advisor took too long to respond. Please try again, or use the saved crop result for the demo.';
      case 'anthropic_auth_failed':
        return 'AI Advisor connection needs attention. Please check Advanced Settings.';
      case 'missing_detection_context':
        return 'No crop image is selected yet. Check a crop image first, then ask the AI Advisor.';
      case 'anthropic_malformed_json':
        return 'AI Advisor returned an unreadable response. Please retry.';
      default:
        return fallback;
    }
  }
}

class AiAssistantException implements Exception {
  final String message;
  final String code;
  final int? statusCode;

  const AiAssistantException(
    this.message, {
    this.code = 'unknown',
    this.statusCode,
  });

  @override
  String toString() => message;
}
