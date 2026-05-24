import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight_capture.dart';
import 'flight_providers.dart';
import 'realtime_providers.dart';

/// Configuration state filters for the Lab curation gallery.
class LabFilter {
  final int? flightId;
  final String viewMode; // 'pending', 'all', 'analyzed', 'rejected'
  final bool showRejected;

  const LabFilter({
    this.flightId,
    this.viewMode = 'pending',
    this.showRejected = false,
  });

  LabFilter copyWith({
    int? Function()? flightId,
    String? viewMode,
    bool? showRejected,
  }) {
    return LabFilter(
      flightId: flightId != null ? flightId() : this.flightId,
      viewMode: viewMode ?? this.viewMode,
      showRejected: showRejected ?? this.showRejected,
    );
  }
}

/// Notifier driving the Lab gallery filters.
class LabFilterNotifier extends Notifier<LabFilter> {
  @override
  LabFilter build() => const LabFilter();

  void setFlightId(int? id) => state = state.copyWith(flightId: () => id);
  void setViewMode(String mode) => state = state.copyWith(viewMode: mode);
  void toggleShowRejected() => state = state.copyWith(showRejected: !state.showRejected);
  void reset() => state = const LabFilter();
}

/// Provider managing active Lab gallery filters.
final labFilterProvider = NotifierProvider<LabFilterNotifier, LabFilter>(LabFilterNotifier.new);

/// StreamProvider combining filtered db lists with live Postgres inserts and status flips.
final labCapturesProvider = StreamProvider<List<FlightCapture>>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  final realtime = ref.watch(realtimeServiceProvider);
  final filter = ref.watch(labFilterProvider);

  final controller = StreamController<List<FlightCapture>>();

  Future<void> updateList() async {
    bool? reviewed;
    bool? rejected;
    bool? aiProcessed;

    if (filter.viewMode == 'pending') {
      reviewed = false;
    } else if (filter.viewMode == 'analyzed') {
      aiProcessed = true;
    } else if (filter.viewMode == 'rejected') {
      reviewed = true;
      rejected = true;
    }

    // Hide rejected captures by default unless explicitly toggled on or viewing rejected list
    bool? queryRejected = rejected;
    if (!filter.showRejected && filter.viewMode != 'rejected') {
      queryRejected = false;
    }

    final captures = await service.getCaptures(
      flightId: filter.flightId,
      reviewed: reviewed,
      rejected: queryRejected,
      aiProcessed: aiProcessed,
    );

    if (!controller.isClosed) controller.add(captures);
  }

  updateList();

  final sub1 = realtime.captureInserts.listen((_) => updateList());
  final sub2 = realtime.captureUpdates.listen((_) => updateList());

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Notifier holding selected capture IDs currently curating.
class SelectedCapturesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => {};

  void toggle(int id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  void clear() {
    state = {};
  }

  void setSelected(Set<int> selected) {
    state = selected;
  }
}

/// Provider managing selected capture IDs.
final selectedCapturesProvider = NotifierProvider<SelectedCapturesNotifier, Set<int>>(SelectedCapturesNotifier.new);
