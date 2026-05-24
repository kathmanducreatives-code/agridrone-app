import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/realtime_service.dart';

/// Provider for managing the singleton instance of RealtimeService.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(Supabase.instance.client);
  service.connect();
  ref.onDispose(() => service.dispose());
  return service;
});

/// StreamProvider exposing the live WebSocket status of Postgres channels.
final realtimeConnectionProvider = StreamProvider<RealtimeConnectionState>((ref) {
  return ref.watch(realtimeServiceProvider).connectionState;
});
