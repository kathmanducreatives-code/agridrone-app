import 'package:latlong2/latlong.dart';

/// Model representing a single geotagged drone flight path capture point.
class FlightPathPoint {
  final int captureId;
  final int flightId;
  final int imageIndex;
  final String? imageUrl;
  final double lat;
  final double lon;
  final double? altitudeM;
  final int gpsFixQuality;
  final int? gpsSatellites;
  final DateTime? uploadedAt;
  final bool aiProcessed;
  final bool rejected;

  const FlightPathPoint({
    required this.captureId,
    required this.flightId,
    required this.imageIndex,
    this.imageUrl,
    required this.lat,
    required this.lon,
    this.altitudeM,
    required this.gpsFixQuality,
    this.gpsSatellites,
    this.uploadedAt,
    required this.aiProcessed,
    required this.rejected,
  });

  LatLng get latLng => LatLng(lat, lon);

  factory FlightPathPoint.fromJson(Map<String, dynamic> json) {
    final rawImageUrl = json['image_url'] as String?;
    String? resolvedImageUrl = rawImageUrl;
    if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
      resolvedImageUrl = (rawImageUrl.startsWith('http://') || rawImageUrl.startsWith('https://'))
          ? rawImageUrl
          : 'https://luvostyizefajbltukkc.supabase.co/storage/v1/object/public/drone-images/${rawImageUrl.startsWith('/') ? rawImageUrl.substring(1) : rawImageUrl}';
    }

    return FlightPathPoint(
      captureId: json['capture_id'] as int,
      flightId: json['flight_id'] as int,
      imageIndex: json['image_index'] as int,
      imageUrl: resolvedImageUrl,
      lat: (json['gps_lat'] as num).toDouble(),
      lon: (json['gps_lon'] as num).toDouble(),
      altitudeM: (json['gps_altitude_m'] as num?)?.toDouble(),
      gpsFixQuality: json['gps_fix_quality'] as int? ?? 0,
      gpsSatellites: json['gps_satellites'] as int?,
      uploadedAt: json['uploaded_at'] != null ? DateTime.tryParse(json['uploaded_at'] as String) : null,
      aiProcessed: json['ai_processed'] as bool? ?? false,
      rejected: json['rejected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'capture_id': captureId,
      'flight_id': flightId,
      'image_index': imageIndex,
      'image_url': imageUrl,
      'gps_lat': lat,
      'gps_lon': lon,
      'gps_altitude_m': altitudeM,
      'gps_fix_quality': gpsFixQuality,
      'gps_satellites': gpsSatellites,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'ai_processed': aiProcessed,
      'rejected': rejected,
    };
  }
}
