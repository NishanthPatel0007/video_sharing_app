import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/platform_helper.dart';

class R2Service {
  // Configuration constants
  static const String workerUrl = 'https://r2.for10cloud.com';
  static const String publicUrl = 'https://r2.for10cloud.com';

  // File size thresholds and limits
  static const int smallFileLimit = 20 * 1024 * 1024;    // 20MB
  static const int mediumFileLimit = 80 * 1024 * 1024;   // 80MB
  static const int largeFileLimit = 200 * 1024 * 1024;   // 200MB
  static const int ultraLargeFileLimit = 400 * 1024 * 1024; // 400MB

  // Maximum file sizes
  static const int maxVideoSize = 500 * 1024 * 1024;     // 500MB for web
  static const int maxMobileVideoSize = 200 * 1024 * 1024; // 200MB for mobile
  static const int maxThumbnailSize = 5 * 1024 * 1024;   // 5MB

  // Retry settings
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 1);

  // Allowed file types with extensions
  static const Map<String, List<String>> allowedTypes = {
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

  // Get optimal timeout based on file size and operation
  Duration getTimeout(int fileSize) {
    if (fileSize <= smallFileLimit) return const Duration(minutes: 2);
    if (fileSize <= mediumFileLimit) return const Duration(minutes: 5);
    if (fileSize <= largeFileLimit) return const Duration(minutes: 10);
    return const Duration(minutes: 15);
  }

  // Get optimal chunk size based on platform and file size
  int getChunkSize(int fileSize, bool isMobile) {
    if (isMobile) {
      if (fileSize <= smallFileLimit) return 1 * 1024 * 1024;  // 1MB chunks
      if (fileSize <= mediumFileLimit) return 2 * 1024 * 1024; // 2MB chunks
      return 4 * 1024 * 1024;                                  // 4MB chunks
    } else {
      if (fileSize <= smallFileLimit) return 2 * 1024 * 1024;  // 2MB chunks
      if (fileSize <= mediumFileLimit) return 4 * 1024 * 1024; // 4MB chunks
      if (fileSize <= largeFileLimit) return 8 * 1024 * 1024;  // 8MB chunks
      return 10 * 1024 * 1024;                                 // 10MB chunks
    }
  }

  // Get optimal concurrent uploads based on platform and file size
  int getConcurrentUploads(int fileSize, bool isMobile) {
    if (isMobile) {
      return fileSize <= mediumFileLimit ? 2 : 1;
    }
    if (fileSize <= smallFileLimit) return 3;
    if (fileSize <= mediumFileLimit) return 2;
    return 1;
  }

  // Main upload method with platform detection and error handling
  Future<String> uploadBytes(
    Uint8List bytes,
    String fileName,
    String contentType, {
    Function(double)? onProgress,
    bool isMobile = false,
  }) async {
    try {
      final fileSize = bytes.length;
      debugPrint('Starting upload of ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB file');

      // Validate file type
      if (!_isValidFileType(contentType)) {
        throw Exception('Invalid file type: $contentType. Allowed types: ${allowedTypes.values.expand((x) => x).join(", ")}');
      }

      // Check size limits based on platform and type
      final maxSize = _getMaxSize(contentType, isMobile);
      if (fileSize > maxSize) {
        throw Exception('File size ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB exceeds limit of ${(maxSize / 1024 / 1024).toStringAsFixed(2)}MB');
      }

      // Use optimized path for small files
      if (fileSize <= 5 * 1024 * 1024) {
        return _uploadSmallFile(bytes, fileName, contentType, onProgress);
      }

      // Get optimized settings for large files
      final chunkSize = getChunkSize(fileSize, isMobile);
      final maxConcurrent = getConcurrentUploads(fileSize, isMobile);
      final timeout = getTimeout(fileSize);

      return _uploadLargeFile(
        bytes,
        fileName,
        contentType,
        chunkSize,
        maxConcurrent,
        timeout,
        onProgress,
      );
    } catch (e) {
      debugPrint('Upload error: $e');
      throw _formatError(e);
    }
  }

  // Handle small file uploads with retry logic
  Future<String> _uploadSmallFile(
    Uint8List bytes,
    String fileName,
    String contentType,
    Function(double)? onProgress,
  ) async {
    final client = http.Client();
    int retryCount = 0;
    
    try {
      while (true) {
        try {
          onProgress?.call(0.1);

          final response = await client.put(
            Uri.parse('$workerUrl/$fileName'),
            headers: {
              'Content-Type': contentType,
              'Content-Length': bytes.length.toString(),
              'Connection': 'keep-alive',
              ...getCustomHeaders(),
            },
            body: bytes,
          ).timeout(const Duration(minutes: 2));

          if (response.statusCode == 200) {
            onProgress?.call(1.0);
            return '$publicUrl/$fileName';
          }

          throw Exception('Upload failed: ${response.statusCode}');
        } catch (e) {
          if (retryCount >= maxRetries || !_shouldRetry(e)) {
            rethrow;
          }
          retryCount++;
          await Future.delayed(initialRetryDelay * retryCount);
        }
      }
    } finally {
      client.close();
    }
  }

  // Handle large file uploads with chunking and retry logic
  Future<String> _uploadLargeFile(
    Uint8List bytes,
    String fileName,
    String contentType,
    int chunkSize,
    int maxConcurrent,
    Duration timeout,
    Function(double)? onProgress,
  ) async {
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
    final totalChunks = (bytes.length / chunkSize).ceil();
    var completedChunks = 0;
    final failedChunks = <int>{};
    final clients = List.generate(maxConcurrent, (_) => http.Client());

    try {
      onProgress?.call(0.01);

      // Retry logic for failed chunks
      for (var attempt = 0; attempt < maxRetries; attempt++) {
        if (attempt > 0) {
          debugPrint('Retry attempt ${attempt + 1} of $maxRetries');
          onProgress?.call(completedChunks / totalChunks);
          await Future.delayed(initialRetryDelay * (attempt + 1));
        }

        failedChunks.clear();

        // Upload chunks in batches
        for (var i = completedChunks; i < totalChunks;) {
          final batch = <Future<void>>[];
          final batchSize = min(maxConcurrent, totalChunks - i);

          // Create batch of concurrent uploads
          for (var j = 0; j < batchSize; j++) {
            final chunkIndex = i + j;
            final start = chunkIndex * chunkSize;
            final end = min(start + chunkSize, bytes.length);
            final chunk = bytes.sublist(start, end);

            batch.add(
              _uploadChunk(
                chunk,
                fileName,
                contentType,
                uploadId,
                chunkIndex,
                totalChunks,
                clients[j],
                timeout,
              ).then((_) {
                completedChunks++;
                onProgress?.call(completedChunks / totalChunks);
              }).catchError((e) {
                debugPrint('Chunk $chunkIndex failed: $e');
                failedChunks.add(chunkIndex);
              })
            );
          }

          await Future.wait(batch);

          // Handle failed chunks
          if (failedChunks.isEmpty) {
            i += batchSize;
          } else if (attempt < maxRetries - 1) {
            debugPrint('Retrying failed chunks: $failedChunks');
            await Future.delayed(initialRetryDelay * (attempt + 1));
            break;
          } else {
            throw Exception('Failed to upload chunks after $maxRetries attempts');
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
      );

      debugPrint('Upload completed successfully');
      return '$publicUrl/$fileName';

    } catch (e) {
      // Cleanup on error
      await _cleanupChunks(fileName, uploadId, totalChunks)
          .catchError((e) => debugPrint('Cleanup error: $e'));
      throw _formatError(e);
    } finally {
      // Cleanup clients
      for (final client in clients) {
        client.close();
      }
    }
  }

  // Upload individual chunk with retry logic
  Future<void> _uploadChunk(
    Uint8List chunk,
    String fileName,
    String contentType,
    String uploadId,
    int partNumber,
    int totalParts,
    http.Client client,
    Duration timeout,
  ) async {
    final uri = Uri.parse('$workerUrl/$fileName');
    int retryCount = 0;

    while (true) {
      try {
        final response = await client.put(
          uri,
          headers: {
            'Content-Type': contentType,
            'X-Upload-Id': uploadId,
            'X-Part-Number': partNumber.toString(),
            'X-Total-Parts': totalParts.toString(),
            'Content-Length': chunk.length.toString(),
            'Connection': 'keep-alive',
            ...getCustomHeaders(),
          },
          body: chunk,
        ).timeout(timeout);

        if (response.statusCode == 200) return;
        throw Exception('Chunk upload failed: ${response.statusCode}');
      } catch (e) {
        if (retryCount >= maxRetries || !_shouldRetry(e)) {
          rethrow;
        }
        retryCount++;
        await Future.delayed(initialRetryDelay * retryCount);
      }
    }
  }

  // Combine uploaded chunks
  Future<void> _combineChunks(
    String fileName,
    String uploadId,
    String contentType,
    int totalChunks,
    int totalSize,
  ) async {
    final client = http.Client();
    int retryCount = 0;

    try {
      while (true) {
        try {
          final response = await client.post(
            Uri.parse('$workerUrl/combine'),
            headers: {
              'Content-Type': 'application/json',
              ...getCustomHeaders(),
            },
            body: {
              'key': fileName,
              'uploadId': uploadId,
              'contentType': contentType,
              'totalChunks': totalChunks.toString(),
              'totalSize': totalSize.toString(),
            },
          ).timeout(const Duration(minutes: 5));

          if (response.statusCode == 200) return;
          throw Exception('Failed to combine chunks: ${response.statusCode}');
        } catch (e) {
          if (retryCount >= maxRetries || !_shouldRetry(e)) {
            rethrow;
          }
          retryCount++;
          await Future.delayed(initialRetryDelay * retryCount);
        }
      }
    } finally {
      client.close();
    }
  }

  // Clean up chunks on failure
  Future<void> _cleanupChunks(String key, String uploadId, int totalParts) async {
    final client = http.Client();
    try {
      for (var i = 0; i < totalParts; i++) {
        try {
          final chunkKey = '$key/$uploadId/part$i';
          await client.delete(Uri.parse('$workerUrl/$chunkKey'))
              .timeout(const Duration(seconds: 30));
        } catch (e) {
          debugPrint('Failed to delete chunk $i: $e');
        }
      }
    } finally {
      client.close();
    }
  }

  // Delete a file from R2
  Future<void> deleteFile(String url) async {
    if (!url.startsWith(publicUrl)) return;

    final client = http.Client();
    int retryCount = 0;

    try {
      while (true) {
        try {
          final uri = Uri.parse(url);
          final filePath = uri.pathSegments.join('/');
          final deleteUri = Uri.parse('$workerUrl/$filePath');

          final response = await client.delete(
            deleteUri,
            headers: getCustomHeaders(),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) return;
          throw Exception('Delete failed: ${response.statusCode}');
        } catch (e) {
          if (retryCount >= maxRetries || !_shouldRetry(e)) {
            rethrow;
          }
          retryCount++;
          await Future.delayed(initialRetryDelay * retryCount);
        }
      }
    } finally {
      client.close();
    }
  }

  // Helper Methods
  bool _isValidFileType(String contentType) {
    final type = contentType.split('/')[0];
    final extensions = allowedTypes[type];
    return extensions?.contains(contentType.toLowerCase()) ?? false;
  }

  int _getMaxSize(String contentType, bool isMobile) {
    if (contentType.startsWith('video/')) {
      return isMobile ? maxMobileVideoSize : maxVideoSize;
    }
    return maxThumbnailSize;
  }

  bool _shouldRetry(dynamic error) {
    final message = error.toString().toLowerCase();
    return message.contains('timeout') ||
           message.contains('connection') ||
           message.contains('network') ||
           message.contains('reset') ||
           message.contains('temporarily_unavailable');
  }

  Exception _formatError(dynamic error) {
    final message = error.toString().toLowerCase();
    
    if (message.contains('timeout')) {
      return Exception('Upload timed out. Please check your connection and try again.');
    }
    if (message.contains('connection')) {
      return Exception('Connection error. Please check your internet and try again.');
    }
    if (message.contains('unauthorized')) {
      return Exception('Unauthorized access. Please log in again.');
    }
    if (message.contains('not found')) {
      return Exception('Resource not found. Please try again.');
    }
    
    return Exception('Upload failed: $error');
  }

  Map<String, String> getCustomHeaders() {
    Map<String, String> headers = {
      'Accept-Ranges': 'bytes',
      'Access-Control-Allow-Origin': '*',
    };

    // Add platform-specific headers
    if (PlatformHelper.isIOSBrowser || PlatformHelper.isSafariBrowser) {
      headers['Range'] = 'bytes=0-';
    }

    return headers;
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

  // Convert file size to human readable format
  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Generate a unique identifier
  String _generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(1000).toString().padLeft(3, '0');
  }
}