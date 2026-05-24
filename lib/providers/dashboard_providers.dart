import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'flight_providers.dart';
import 'realtime_providers.dart';
import '../models/detection.dart';

// ── Authentication State ─────────────────────────────────────

class AuthState {
  final bool isAuthenticated;
  final String? email;

  const AuthState({
    required this.isAuthenticated,
    this.email,
  });

  const AuthState.unauthenticated()
      : isAuthenticated = false,
        email = null;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.unauthenticated();

  void login(String email, String password) {
    state = AuthState(isAuthenticated: true, email: email);
  }

  void logout() {
    state = const AuthState.unauthenticated();
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// ── Navigation State ─────────────────────────────────────────

class CurrentTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) {
    state = index;
  }
}

final currentTabProvider = NotifierProvider<CurrentTabNotifier, int>(CurrentTabNotifier.new);

// ── Dashboard Metrics Stream Providers ──────────────────────────

/// StreamProvider evaluating the total captures awaiting operator review.
final pendingReviewCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);
  
  final controller = StreamController<int>();
  
  service.getPendingReviewCount().then((val) {
    if (!controller.isClosed) controller.add(val);
  });
  
  final sub1 = realtime.captureUpdates.listen((_) async {
    final val = await service.getPendingReviewCount();
    if (!controller.isClosed) controller.add(val);
  });
  
  final sub2 = realtime.captureInserts.listen((_) async {
    final val = await service.getPendingReviewCount();
    if (!controller.isClosed) controller.add(val);
  });
  
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// StreamProvider evaluating the total captures successfully analyzed today.
final analyzedTodayCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);
  
  final controller = StreamController<int>();
  
  service.getAnalyzedTodayCount().then((val) {
    if (!controller.isClosed) controller.add(val);
  });
  
  final sub = realtime.captureUpdates.listen((_) async {
    final val = await service.getAnalyzedTodayCount();
    if (!controller.isClosed) controller.add(val);
  });
  
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// StreamProvider evaluating the total detections reported today.
final todayDetectionsCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);
  
  final controller = StreamController<int>();
  
  service.getTodayDetectionsCount().then((val) {
    if (!controller.isClosed) controller.add(val);
  });
  
  final sub = realtime.detectionInserts.listen((_) async {
    final val = await service.getTodayDetectionsCount();
    if (!controller.isClosed) controller.add(val);
  });
  
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  
  return controller.stream;
});

// ── Derived threat levels ──────────────────────────────────────

enum AlertLevel { low, medium, high }

/// FutureProvider evaluating threat levels in the last 24 hours.
final diseaseAlertLevelProvider = FutureProvider<AlertLevel>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);
  
  final sub = realtime.detectionInserts.listen((_) => ref.invalidateSelf());
  ref.onDispose(() => sub.cancel());

  final list = await service.getRecentDetections(limit: 100);
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(hours: 24));
  final todayList = list.where((d) => d.detectedAt.isAfter(yesterday)).toList();

  if (todayList.any((d) => d.confidence > 0.85)) {
    return AlertLevel.high;
  } else if (todayList.any((d) => d.confidence > 0.60)) {
    return AlertLevel.medium;
  }
  return AlertLevel.low;
});

// ── Horizontals List Recent Detections ─────────────────────────

/// FutureProvider supplying the horizontal strip scroll detections on the dashboard.
final recentDetectionsProvider = FutureProvider<List<Detection>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  final sub1 = realtime.detectionInserts.listen((_) => ref.invalidateSelf());
  final sub2 = realtime.captureUpdates.listen((_) => ref.invalidateSelf());
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
  });

  return service.getRecentDetections(limit: 10);
});

// ── Daily Capture Chart statistics ─────────────────────────────

/// FutureProvider supplying aggregated analytics for analyzed counts per day.
final dailyChartDataProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);

  final sub = realtime.captureUpdates.listen((_) => ref.invalidateSelf());
  ref.onDispose(() => sub.cancel());

  return service.getDailyAnalyzedCounts(7);
});
