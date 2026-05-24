class DroneTelemetry {
  final String status; // "ONLINE" | "OFFLINE" | "SCANNING" | "ERROR"
  final String ip;
  final int battery;
  final int wifiSignal; // dBm
  final double gpsLat;
  final double gpsLng;
  final bool gpsValid;
  final double uploadProgress; // 0.0 to 1.0
  final int uploadedCount;
  final int totalCount;
  final DateTime lastSync;

  DroneTelemetry({
    required this.status,
    required this.ip,
    required this.battery,
    required this.wifiSignal,
    required this.gpsLat,
    required this.gpsLng,
    required this.gpsValid,
    required this.uploadProgress,
    required this.uploadedCount,
    required this.totalCount,
    required this.lastSync,
  });

  factory DroneTelemetry.mockOnline({
    required int uploaded,
    required int total,
    required DateTime lastActive,
  }) {
    return DroneTelemetry(
      status: 'ONLINE',
      ip: '192.168.4.1',
      battery: 88,
      wifiSignal: -58,
      gpsLat: 27.7172,
      gpsLng: 85.3240,
      gpsValid: true,
      uploadProgress: total == 0 ? 0.0 : uploaded / total,
      uploadedCount: uploaded,
      totalCount: total,
      lastSync: lastActive,
    );
  }
}
