import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connection state flags representing active Realtime streams.
enum RealtimeConnectionState { connecting, connected, disconnected, error }

/// Service supervising real-time PostgreSQL events for flight captures and disease detections.
class RealtimeService {
  final SupabaseClient _client;
  RealtimeChannel? _capturesChannel;
  RealtimeChannel? _detectionsChannel;

  final _captureInserts   = StreamController<Map<String, dynamic>>.broadcast();
  final _captureUpdates   = StreamController<Map<String, dynamic>>.broadcast();
  final _detectionInserts = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionState  = StreamController<RealtimeConnectionState>.broadcast();

  RealtimeService(this._client);

  Stream<Map<String, dynamic>> get captureInserts   => _captureInserts.stream;
  Stream<Map<String, dynamic>> get captureUpdates   => _captureUpdates.stream;
  Stream<Map<String, dynamic>> get detectionInserts => _detectionInserts.stream;
  Stream<RealtimeConnectionState> get connectionState => _connectionState.stream;

  /// Establishes subscription channels and registers Postgres INSERT and UPDATE callbacks.
  Future<void> connect() async {
    debugPrint('[AgriDrone] Initializing curation Realtime services...');
    _connectionState.add(RealtimeConnectionState.connecting);

    try {
      _capturesChannel = _client.channel('public:flight_captures')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'flight_captures',
          callback: (payload) {
            debugPrint('[AgriDrone] Realtime capture INSERT event');
            _captureInserts.add(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'flight_captures',
          callback: (payload) {
            debugPrint('[AgriDrone] Realtime capture UPDATE event');
            _captureUpdates.add(payload.newRecord);
          },
        );

      _capturesChannel!.subscribe((status, [error]) {
        debugPrint('[AgriDrone] Captures RealtimeStatus: $status, Error: $error');
        if (status == RealtimeSubscribeStatus.subscribed) {
          _connectionState.add(RealtimeConnectionState.connected);
        } else if (status == RealtimeSubscribeStatus.channelError ||
                   status == RealtimeSubscribeStatus.closed) {
          _connectionState.add(RealtimeConnectionState.disconnected);
        }
      });

      _detectionsChannel = _client.channel('public:detections')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'detections',
          callback: (payload) {
            debugPrint('[AgriDrone] Realtime detections INSERT event');
            _detectionInserts.add(payload.newRecord);
          },
        );

      _detectionsChannel!.subscribe();
    } catch (e) {
      debugPrint('[AgriDrone] Error starting Realtime streams: $e');
      _connectionState.add(RealtimeConnectionState.error);
    }
  }

  /// Re-negotiates active subscription connections.
  Future<void> reconnect() async {
    debugPrint('[AgriDrone] Force re-subscribing channels');
    await disconnect();
    await connect();
  }

  /// Disables channels and stops PostgreSQL updates listening.
  Future<void> disconnect() async {
    debugPrint('[AgriDrone] Removing active Realtime channels');
    try {
      if (_capturesChannel != null) {
        await _client.removeChannel(_capturesChannel!);
        _capturesChannel = null;
      }
      if (_detectionsChannel != null) {
        await _client.removeChannel(_detectionsChannel!);
        _detectionsChannel = null;
      }
    } catch (e) {
      debugPrint('[AgriDrone] Error removing channel subscriptions: $e');
    }
  }

  /// Closes internal stream channels to prevent memory leakage.
  void dispose() {
    disconnect();
    _captureInserts.close();
    _captureUpdates.close();
    _detectionInserts.close();
    _connectionState.close();
  }
}
