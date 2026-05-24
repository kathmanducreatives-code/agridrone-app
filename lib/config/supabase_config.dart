// SECURITY NOTE:
// For production, these values should be passed via --dart-define at build time
// (e.g. flutter build web --dart-define=SUPABASE_URL=... ).
// Hard-coded values here are acceptable only for an academic prototype.

/// Central configuration for Supabase and HuggingFace API integration.
class SupabaseConfig {
  SupabaseConfig._();

  // ── Supabase ───────────────────────────────────────────────
  static const String url = 'https://luvostyizefajbltukkc.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1dm9zdHlpemVmYWpibHR1a2tjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxMDA1NDgsImV4cCI6MjA5MjY3NjU0OH0.FcihW48l30A7sxv5IC5GdekKCNTmFo2xEnAebBen5UI';
  static const String storageBucket = 'drone-images';

  // ── HuggingFace FastAPI ────────────────────────────────────
  static const String huggingFaceBaseUrl = 'https://prasidhaaaa-aimodel.hf.space';
  static const String huggingFaceWebhookPath = '/webhook/new_flight';
  static const String huggingFaceToken = 'agridrone2024';

  static String get huggingFaceWebhookUrl => '$huggingFaceBaseUrl$huggingFaceWebhookPath';
  static String get huggingFacePredictUrl => '$huggingFaceBaseUrl/predict';
  static String get huggingFaceHealthUrl  => '$huggingFaceBaseUrl/health';
}
