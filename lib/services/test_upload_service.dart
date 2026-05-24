import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/test_upload.dart';
import '../models/test_detection.dart';

/// Service overseeing user test uploads and interactions with the Supabase database.
class TestUploadService {
  final _client = Supabase.instance.client;
  static const String _bucket = 'drone-images';
  static const String _subfolder = 'test-uploads';

  /// Uploads binary image bytes to Supabase Storage and returns the public URL.
  Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final uuid = _generateUuid();
    final ext = filename.split('.').last.toLowerCase();
    final storagePath = '$_subfolder/$uuid.$ext';

    await _client.storage.from(_bucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: false,
      ),
    );

    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  /// Creates a record entry in the test_uploads table via Supabase RPC. Returns the new row id.
  Future<int> createTestUploadRow({
    required String uuid,
    required String filename,
    required String imageUrl,
    required int sizeBytes,
    String? notes,
  }) async {
    final result = await _client.rpc('create_test_upload', params: {
      'p_upload_uuid': uuid,
      'p_source_filename': filename,
      'p_image_url': imageUrl,
      'p_image_size': sizeBytes,
      'p_notes': notes,
    });
    return result as int;
  }

  /// Marks a test upload record ready for AI analysis.
  Future<void> requestAnalysis(int uploadId) async {
    await _client.rpc('request_test_analysis', params: {'upload_id': uploadId});
  }

  /// Deletes a test upload from the database and performs a best-effort file cleanup in storage.
  Future<void> deleteTestUpload(int uploadId) async {
    try {
      final res = await _client
          .from('test_uploads')
          .select('image_url')
          .eq('id', uploadId)
          .maybeSingle();

      if (res != null) {
        final imageUrl = res['image_url'] as String;
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;
        final index = pathSegments.indexOf('test-uploads');
        if (index != -1 && index + 1 < pathSegments.length) {
          final storagePath = pathSegments.sublist(index).join('/');
          await _client.storage.from(_bucket).remove([storagePath]);
          debugPrint('[AgriDrone] Successfully removed storage file: $storagePath');
        }
      }
    } catch (e) {
      debugPrint('[AgriDrone] Best-effort storage deletion failed for upload $uploadId: $e');
    }

    // Nuke database entry cascading down to test detections
    await _client.rpc('delete_test_upload', params: {'upload_id': uploadId});
  }

  /// Fetches a list of historical test uploads and aggregate statistics from the summary view.
  Future<List<TestUpload>> getAllTestUploads({int limit = 100}) async {
    final res = await _client
        .from('test_upload_summary')
        .select()
        .order('uploaded_at', ascending: false)
        .limit(limit);
    return (res as List).map((j) => TestUpload.fromJson(j)).toList();
  }

  /// Retrieves a list of disease bounding boxes detected on a specific test upload.
  Future<List<TestDetection>> getDetectionsForUpload(int uploadId) async {
    final res = await _client
        .from('test_detections')
        .select()
        .eq('test_upload_id', uploadId)
        .order('confidence', ascending: false);
    return (res as List).map((j) => TestDetection.fromJson(j)).toList();
  }

  /// Generates a standard cryptographically shaped UUID v4 compliant string.
  String _generateUuid() {
    final random = Random.secure();
    final hexDigits = '0123456789abcdef';

    String generateHex(int length) {
      return List.generate(length, (_) => hexDigits[random.nextInt(16)]).join();
    }

    // Format: 8-4-4-4-12
    return '${generateHex(8)}-${generateHex(4)}-4${generateHex(3)}-8${generateHex(3)}-${generateHex(12)}';
  }
}
