/// Central registry of all local asset paths used throughout the app.
///
/// All assets are bundled locally — no external hotlinks or copyrighted
/// remote images. Asset directories are declared in pubspec.yaml.
class AppAssets {
  AppAssets._();

  // ── Illustrations ─────────────────────────────────────────────
  /// Dashboard hero — Nepali farmer with drone scanning paddy field (landscape).
  static const dashboardHero =
      'assets/illustrations/dashboard_nepali_farmer_drone_field.jpg';

  /// AI chat welcome — farmer with chat bubbles and drone overhead.
  static const aiChatWelcome =
      'assets/illustrations/ai_chat_welcome_farmer.jpg';

  /// Empty state for crop images page — farmer with phone showing image placeholder.
  static const emptyCropImages =
      'assets/illustrations/empty_crop_images.jpg';

  /// Empty state for drone flights page — farmer with flight logs on tablet.
  static const emptyDroneFlights =
      'assets/illustrations/empty_drone_flights.png';

  /// Empty state for reports page — farmer with blank clipboard.
  static const emptyReports =
      'assets/illustrations/empty_reports.png';

  /// Weather unavailable — monsoon rain over terraced paddy field.
  static const weatherMonsoon =
      'assets/illustrations/weather_paddy_monsoon.png';

  /// Crop health AI scan — leaf with magnifying lens and AI patterns.
  static const cropHealthScan =
      'assets/illustrations/crop_health_ai_scan.png';

  /// Report header banner — drone over paddy field with data overlays.
  static const reportHeader =
      'assets/illustrations/report_header_paddy_drone_ai.png';

  // ── Mascots ───────────────────────────────────────────────────
  /// Farmer AI advisor — full body with drone and leaf icon.
  static const farmerAdvisor =
      'assets/mascots/farmer_ai_advisor.jpg';

  /// Farmer portrait — close-up bust for avatars and headers.
  static const farmerPortrait =
      'assets/mascots/farmer_mascot_portrait.jpg';
}
