import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/test_upload.dart';
import '../models/test_detection.dart';
import '../services/test_upload_service.dart';

/// Provider for accessing the singleton [TestUploadService].
final testUploadServiceProvider = Provider<TestUploadService>((ref) {
  return TestUploadService();
});

/// StreamProvider delivering real-time test uploads feed.
/// Combines immediate fetching with a 5-second periodic database poll.
final allTestUploadsProvider = StreamProvider<List<TestUpload>>((ref) {
  final service = ref.watch(testUploadServiceProvider);
  final controller = StreamController<List<TestUpload>>();

  Future<void> refresh() async {
    try {
      final uploads = await service.getAllTestUploads();
      if (!controller.isClosed) {
        controller.add(uploads);
      }
    } catch (e) {
      debugPrint('[AgriDrone] Failed to fetch test uploads: $e');
    }
  }

  // First fetch
  refresh();

  // Polling every 5 seconds as fallback/reassurance of database synchronization
  final timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Notifier state for list of pending files picked by the user.
class PendingFilesNotifier extends Notifier<List<PendingFile>> {
  @override
  List<PendingFile> build() => [];

  void set(List<PendingFile> files) {
    state = files;
  }

  void add(List<PendingFile> files) {
    state = [...state, ...files];
  }

  void updateFile(PendingFile file, UploadStatus status, {List<TestDetection>? detections, String? error}) {
    state = state.map((f) {
      if (f.name == file.name && f.sizeBytes == file.sizeBytes) {
        return f.copyWith(
          status: status,
          detections: detections,
          error: error,
        );
      }
      return f;
    }).toList();
  }

  void clear() {
    state = [];
  }
}

/// Provider for list of pending files picked by the user.
final pendingFilesProvider = NotifierProvider<PendingFilesNotifier, List<PendingFile>>(PendingFilesNotifier.new);

/// Represents a single file awaiting/running through the upload and analysis process.
class PendingFile {
  final String name;
  final Uint8List bytes;
  final int sizeBytes;
  UploadStatus status;
  String? error;
  int? testUploadId;
  List<TestDetection>? detections;

  PendingFile({
    required this.name,
    required this.bytes,
    required this.sizeBytes,
    this.status = UploadStatus.queued,
    this.error,
    this.testUploadId,
    this.detections,
  });

  PendingFile copyWith({
    String? name,
    Uint8List? bytes,
    int? sizeBytes,
    UploadStatus? status,
    String? error,
    int? testUploadId,
    List<TestDetection>? detections,
  }) {
    return PendingFile(
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      testUploadId: testUploadId ?? this.testUploadId,
      detections: detections ?? this.detections,
    );
  }
}

/// Status states for image files undergoing uploading and prediction.
enum UploadStatus {
  queued,
  uploading,
  analyzing,
  complete,
  failed,
}
