import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UploadService {
  static const String _workerUrl = 'https://r2.for10cloud.com';
  static const String _publicUrl = 'https://r2.for10cloud.com';
  
  // File size limits
  static const int maxVideoSize = 500 * 1024 * 1024;     // 500MB for web
  static const int maxMobileVideoSize = 200 * 1024 * 1024; // 200MB for mobile
  static const int maxThumbnailSize = 5 * 1024 * 1024;   // 5MB
  static const int maxRetries = 3;
  
  // Content types mapping
  static const Map<String, List<String>> _allowedTypes = {
    'video': [
      'video/mp4',
      'video/quicktime',
      'video/x-msvideo',
      'video/x-matroska',
      'video/mov',
      'video/m4v',
      'video/mpeg',
      'video/webm',
    ],
    'image': [
      'image/jpeg',
      'image/png',
      'image/jpg',
      'image/webp',
    ]
  };

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get optimal chunk size based on file size and platform
  int _getChunkSize(int fileSize, bool isMobile) {
    if (isMobile) {
      if (fileSize <= 20 * 1024 * 1024) return 1 * 1024 * 1024;  // 1MB
      if (fileSize <= 50 * 1024 * 1024) return 2 * 1024 * 1024;  // 2MB
      return 4 * 1024 * 1024;  // 4MB
    } else {
      if (fileSize <= 100 * 1024 * 1024) return 5 * 1024 * 1024;  // 5MB
      if (fileSize <= 200 * 1024 * 1024) return 10 * 1024 * 1024; // 10MB
      return 20 * 1024 * 1024; // 20MB
    }
  }

  // Get timeout duration based on file size
  Duration _getTimeout(int fileSize) {
    if (fileSize <= 50 * 1024 * 1024) return const Duration(minutes: 5);
    if (fileSize <= 200 * 1024 * 1024) return const Duration(minutes: 10);
    return const Duration(minutes: 15);
  }

  Future<String> uploadBytes(
    Uint8List bytes,
    String fileName,
    String contentType, {
    Function(double)? onProgress,
    bool isMobile = false,
    bool isRetry = false,
  }) async {
    try {
      // Validate file type
      if (!isValidFileType(contentType)) {
        throw Exception('Invalid file type: $contentType');
      }

      // Check file size
      final maxSize = _getMaxFileSize(contentType, isMobile);
      if (bytes.length > maxSize) {
        throw Exception('File size exceeds ${maxSize ~/ (1024 * 1024)}MB limit');
      }

      // Use fast path for small files
      if (bytes.length <= 5 * 1024 * 1024) {
        return _uploadSmallFile(bytes, fileName, contentType, onProgress);
      }

      // Use chunked upload for larger files
      final chunkSize = _getChunkSize(bytes.length, isMobile);
      final timeout = _getTimeout(bytes.length);

      return _uploadLargeFile(
        bytes,
        fileName,
        contentType,
        chunkSize,
        timeout,
        onProgress,
      );

    } catch (e) {
      debugPrint('Upload error: $e');
      if (!isRetry && _shouldRetry(e)) {
        debugPrint('Retrying upload...');
        return uploadBytes(
          bytes,
          fileName,
          contentType,
          onProgress: onProgress,
          isMobile: isMobile,
          isRetry: true,
        );
      }
      throw Exception('Upload failed: $e');
    }
  }

  Future<String> _uploadSmallFile(
    Uint8List bytes,
    String fileName,
    String contentType,
    Function(double)? onProgress,
  ) async {
    final client = http.Client();
    try {
      onProgress?.call(0.1);
      
      final token = await _getAuthToken();
      final response = await client.put(
        Uri.parse('$_workerUrl/$fileName'),
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length.toString(),
          'Authorization': 'Bearer $token',
          'Connection': 'keep-alive',
        },
        body: bytes,
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        onProgress?.call(1.0);
        return '$_publicUrl/$fileName';
      }

      throw Exception('Upload failed with status: ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  Future<String> _uploadLargeFile(
    Uint8List bytes,
    String fileName,
    String contentType,
    int chunkSize,
    Duration timeout,
    Function(double)? onProgress,
  ) async {
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
    final totalChunks = (bytes.length / chunkSize).ceil();
    var completedChunks = 0;
    final failedChunks = <int>{};
    final token = await _getAuthToken();

    try {
      onProgress?.call(0.01);  // Initial progress

      // Upload chunks with retry logic
      for (var attempt = 0; attempt < maxRetries; attempt++) {
        if (attempt > 0) {
          debugPrint('Chunk upload attempt ${attempt + 1} of $maxRetries');
          await Future.delayed(Duration(seconds: 3 * attempt));
        }

        failedChunks.clear();
        
        // Upload chunks
        for (var i = completedChunks; i < totalChunks;) {
          final start = i * chunkSize;
          final end = min(start + chunkSize, bytes.length);
          final chunk = bytes.sublist(start, end);

          try {
            await _uploadChunk(
              chunk,
              fileName,
              contentType,
              uploadId,
              i,
              totalChunks,
              token,
              timeout,
            );
            
            completedChunks++;
            onProgress?.call(completedChunks / totalChunks);
            i++;
            
          } catch (e) {
            debugPrint('Chunk $i upload failed: $e');
            failedChunks.add(i);
            
            if (!_shouldRetryChunk(e)) {
              throw Exception('Fatal chunk upload error: $e');
            }
            
            if (failedChunks.length > totalChunks * 0.2) {
              throw Exception('Too many chunk failures');
            }
          }
        }

        if (failedChunks.isEmpty) break;
      }

      // Combine chunks
      await _combineChunks(
        fileName,
        uploadId,
        contentType,
        totalChunks,
        bytes.length,
        token,
      );

      debugPrint('Upload completed successfully');
      return '$_publicUrl/$fileName';

    } catch (e) {
      // Cleanup on error
      await _cleanupFailedUpload(fileName, uploadId, totalChunks)
          .catchError((e) => debugPrint('Cleanup error: $e'));
      throw Exception('Upload failed: $e');
    }
  }

  Future<void> _uploadChunk(
    Uint8List chunk,
    String fileName,
    String contentType,
    String uploadId,
    int partNumber,
    int totalParts,
    String token,
    Duration timeout,
  ) async {
    final uri = Uri.parse('$_workerUrl/$fileName');
    final client = http.Client();
    
    try {
      final response = await client.put(
        uri,
        headers: {
          'Content-Type': contentType,
          'Authorization': 'Bearer $token',
          'X-Upload-Id': uploadId,
          'X-Part-Number': partNumber.toString(),
          'X-Total-Parts': totalParts.toString(),
          'Content-Length': chunk.length.toString(),
          'Connection': 'keep-alive',
        },
        body: chunk,
      ).timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Chunk upload failed: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  Future<void> _combineChunks(
    String fileName,
    String uploadId,
    String contentType,
    int totalChunks,
    int totalSize,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$_workerUrl/combine'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: {
        'fileName': fileName,
        'uploadId': uploadId,
        'contentType': contentType,
        'totalChunks': totalChunks.toString(),
        'totalSize': totalSize.toString(),
      },
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to combine chunks: ${response.statusCode}');
    }
  }

  Future<void> _cleanupFailedUpload(
    String fileName,
    String uploadId,
    int totalChunks,
  ) async {
    final token = await _getAuthToken();
    
    for (var i = 0; i < totalChunks; i++) {
      try {
        await http.delete(
          Uri.parse('$_workerUrl/chunks/$fileName/$uploadId/part$i'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (e) {
        debugPrint('Failed to cleanup chunk $i: $e');
      }
    }
  }

  Future<String> _getAuthToken() async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw Exception('Not authenticated');
    return token;
  }

  bool isValidFileType(String contentType) {
    final type = contentType.split('/')[0];
    final allowedExtensions = _allowedTypes[type];
    return allowedExtensions?.contains(contentType.toLowerCase()) ?? false;
  }

  int _getMaxFileSize(String contentType, bool isMobile) {
    final type = contentType.split('/')[0];
    if (type == 'video') {
      return isMobile ? maxMobileVideoSize : maxVideoSize;
    }
    return maxThumbnailSize;
  }

  bool _shouldRetry(dynamic error) {
    final message = error.toString().toLowerCase();
    return message.contains('timeout') ||
           message.contains('network') ||
           message.contains('connection') ||
           message.contains('temporarily unavailable');
  }

  bool _shouldRetryChunk(dynamic error) {
    final message = error.toString().toLowerCase();
    return _shouldRetry(error) &&
           !message.contains('not found') &&
           !message.contains('unauthorized') &&
           !message.contains('forbidden');
  }

  Future<void> deleteFile(String url) async {
    if (!url.startsWith(_publicUrl)) return;

    final token = await _getAuthToken();
    final client = http.Client();
    
    try {
      final uri = Uri.parse(url);
      final filePath = uri.path;
      final deleteUri = Uri.parse('$_workerUrl$filePath');

      final response = await client.delete(
        deleteUri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Delete failed: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  String generateVideoPath(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFileName = _sanitizeFileName(originalFileName);
    return 'videos/$timestamp\_$cleanFileName';
  }

  String generateThumbnailPath(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFileName = _sanitizeFileName(originalFileName);
    return 'thumbnails/$timestamp\_$cleanFileName';
  }

  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\._-]'), '_')
        .toLowerCase();
  }
}