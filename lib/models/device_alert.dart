class DeviceAlert {
  final int id;
  final String deviceId;
  final String eventType; // "offline", "failed_upload", "detection", "info"
  final String severity; // "CRITICAL", "WARNING", "INFO"
  final String message;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  DeviceAlert({
    required this.id,
    required this.deviceId,
    required this.eventType,
    required this.severity,
    required this.message,
    this.payload,
    required this.createdAt,
  });

  factory DeviceAlert.fromJson(Map<String, dynamic> json) {
    return DeviceAlert(
      id: json['id'] as int,
      deviceId: json['device_id'] as String? ?? 'esp32-agridrone-01',
      eventType: json['event_type'] as String? ?? 'info',
      severity: json['severity'] as String? ?? 'INFO',
      message: json['message'] as String? ?? '',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload'] as Map) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
