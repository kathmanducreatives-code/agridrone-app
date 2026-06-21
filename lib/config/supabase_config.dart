// SECURITY NOTE:
// For production, these values should be passed via --dart-define at build time
// (e.g. flutter build web --dart-define=SUPABASE_URL=... ).
// Hard-coded values here are acceptable only for an academic prototype.
//
// TODO(phase-1-hardening): before real deployment, rotate exposed Supabase
// service-role/API secrets and replace these prototype fallbacks with
// String.fromEnvironment-backed values from .env.example.

/// Central configuration for cloud records and crop analysis integration.
class SupabaseConfig {
  SupabaseConfig._();

  // ── Cloud records ──────────────────────────────────────────
  static const String url = 'https://luvostyizefajbltukkc.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1dm9zdHlpemVmYWpibHR1a2tjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxMDA1NDgsImV4cCI6MjA5MjY3NjU0OH0.FcihW48l30A7sxv5IC5GdekKCNTmFo2xEnAebBen5UI';
  static const String storageBucket = 'drone-images';

  // ── Image analysis ─────────────────────────────────────────
  static const String huggingFaceBaseUrl =
      'https://prasidhaaaa-aimodel.hf.space';
  static const String huggingFaceWebhookPath = '/webhook/new_flight';
  static const String huggingFaceToken = 'agridrone2024';

  // ── AI Advisor backend ────────────────────────────────────
  // Server-side only: Flutter calls /ai/* and never sees AI provider keys.
  static const String aiAssistantBaseUrl = String.fromEnvironment(
    'AGRIDRONE_AI_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001',
  );

  static String get huggingFaceWebhookUrl =>
      '$huggingFaceBaseUrl$huggingFaceWebhookPath';
  static String get huggingFacePredictUrl => '$huggingFaceBaseUrl/predict';
  static String get huggingFaceHealthUrl => '$huggingFaceBaseUrl/health';
  static String get aiAssistantHealthUrl => '$aiAssistantBaseUrl/health';
  static String get aiExplainAnalysisUrl =>
      '$aiAssistantBaseUrl/ai/explain-analysis';
  static String get aiRecommendationUrl =>
      '$aiAssistantBaseUrl/ai/recommendation';
  static String get aiReportUrl => '$aiAssistantBaseUrl/ai/report';
  static String get aiJudgeSummaryUrl => '$aiAssistantBaseUrl/ai/judge-summary';
  static String get aiChatUrl => '$aiAssistantBaseUrl/ai/chat';
  static String get aiFeedbackUrl => '$aiAssistantBaseUrl/ai/feedback';
}
