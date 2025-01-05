import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class R2Service {
  final String workerUrl = 'https://r2.for10cloud.com';
  final String publicUrl = 'https://r2.for10cloud.com';
  final String bucketName = 'cloudfarebuckey2002';
  final String accountId = '666bfc1258e239123f4ced095cb958e4';

  // File size thresholds
  static const int smallFileLimit = 20 * 1024 * 1024;    // 20MB
  static const int mediumFileLimit = 80 * 1024 * 1024;   // 80MB
  static const int largeFileLimit = 200 * 1024 * 1024;   // 200MB
  static const int ultraLargeFileLimit = 400 * 1024 * 1024; // 400MB

  // Maximum file sizes
  static const int maxVideoSize = 500 * 1024 * 1024;     // 500MB
  static const int maxThumbnailSize = 5 * 1024 * 1024;   // 5MB

  // Optimized timeout settings for large files
  Duration getTimeout(int fileSize) {
    if (fileSize <= smallFileLimit) return const Duration(minutes: 2);      // 2 minutes
    if (fileSize <= mediumFileLimit) return const Duration(minutes: 5);     // 5 minutes
    if (fileSize <= largeFileLimit) return const Duration(minutes: 10);     // 10 minutes
    return const Duration(minutes: 15);                                     // 15 minutes
  }

  // Optimized chunk sizes
  int getChunkSize(int fileSize) {
    if (fileSize <= smallFileLimit) return 2 * 1024 * 1024;      // 2MB chunks
    if (fileSize <= mediumFileLimit) return 4 * 1024 * 1024;     // 4MB chunks
    if (fileSize <= largeFileLimit) return 8 * 1024 * 1024;      // 8MB chunks
    return 10 * 1024 * 1024;                                     // 10MB chunks
  }

  // Reduced concurrent uploads for stability
  int getConcurrentUploads(int fileSize) {
    if (fileSize <= smallFileLimit) return 3;
    if (fileSize <= mediumFileLimit) return 2;
    return 1; // Single upload for large files
  }

  // Enhanced error handling settings
  static const int maxRetries = 5;
  static const Duration retryDelay = Duration(seconds: 10);

  // Allowed file types
  static final List<String> allowedVideoTypes = [
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska'
  ];

  static final List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/jpg'
  ];

  Future<String> uploadBytes(
    Uint8List bytes,
    String fileName,
    String contentType, {
    Function(double)? onProgress
  }) async {
    try {
      final fileSize = bytes.length;
      print('Starting upload of ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB file');

      // Validate file size
      final maxSize = contentType.startsWith('video/') ? maxVideoSize : maxThumbnailSize;
      if (fileSize > maxSize) {
        throw Exception('File size exceeds the maximum limit');
      }

      // Validate file type
      final allowedTypes = contentType.startsWith('video/') ? allowedVideoTypes : allowedImageTypes;
      if (!isValidFileType(contentType, allowedTypes)) {
        throw Exception('Invalid file type: $contentType');
      }

      // Fast path for small files
      if (fileSize <= 5 * 1024 * 1024) {
        return _uploadSmallFile(bytes, fileName, contentType, onProgress);
      }

      // Get optimized settings
      final chunkSize = getChunkSize(fileSize);
      final maxConcurrent = getConcurrentUploads(fileSize);
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
      print('Upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }

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

    print('\nUpload configuration:');
    print('File size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
    print('Chunk size: ${(chunkSize / 1024 / 1024).toStringAsFixed(2)}MB');
    print('Total chunks: $totalChunks');
    print('Concurrent uploads: $maxConcurrent');
    print('Timeout per chunk: ${timeout.inSeconds}s\n');

    final clients = List.generate(maxConcurrent, (_) => http.Client());

    try {
      onProgress?.call(0.01);

      for (var attempt = 0; attempt < maxRetries; attempt++) {
        if (attempt > 0) {
          print('Attempt ${attempt + 1} of $maxRetries');
          onProgress?.call(completedChunks / totalChunks);
        }

        failedChunks.clear();
        
        for (var i = completedChunks; i < totalChunks;) {
          final batch = <Future<void>>[];
          final batchSize = min(maxConcurrent, totalChunks - i);

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
                print('Chunk $chunkIndex failed: $e');
                failedChunks.add(chunkIndex);
              })
            );
          }

          await Future.wait(batch);
          
          if (failedChunks.isEmpty) {
            i += batchSize;
          } else if (attempt < maxRetries - 1) {
            final delay = retryDelay * (attempt + 1);
            print('Retrying failed chunks after ${delay.inSeconds}s delay...');
            await Future.delayed(delay);
            break;
          } else {
            throw Exception('Failed to upload chunks after multiple retries');
          }
        }

        if (failedChunks.isEmpty) break;
      }

      print('Upload completed successfully');
      return '$publicUrl/$fileName';
    } finally {
      for (final client in clients) {
        client.close();
      }
    }
  }

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
    
    final response = await client.put(
      uri,
      headers: {
        'Content-Type': contentType,
        'X-Upload-Id': uploadId,
        'X-Part-Number': partNumber.toString(),
        'X-Total-Parts': totalParts.toString(),
        'Content-Length': chunk.length.toString(),
        'Connection': 'keep-alive',
        'Keep-Alive': 'timeout=${timeout.inSeconds}',
      },
      body: chunk,
    ).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('Chunk upload failed: ${response.statusCode}');
    }
  }

  Future<String> _uploadSmallFile(
    Uint8List bytes,
    String fileName,
    String contentType,
    Function(double)? onProgress
  ) async {
    final client = http.Client();
    try {
      onProgress?.call(0.1);
      
      final response = await client.put(
        Uri.parse('$workerUrl/$fileName'),
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length.toString(),
          'Connection': 'keep-alive',
        },
        body: bytes,
      ).timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        onProgress?.call(1.0);
        return '$publicUrl/$fileName';
      }
      throw Exception('Upload failed: ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  Future<void> deleteFile(String fileUrl) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments.join('/');
      
      final deleteUri = Uri.parse('$workerUrl/$filePath');
      print('Attempting to delete: $filePath');

      final response = await client.delete(
        deleteUri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Delete failed: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  bool isValidFileType(String contentType, List<String> allowedTypes) {
    return allowedTypes.contains(contentType.toLowerCase());
  }

  String generateVideoPath(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFileName = sanitizeFileName(originalFileName);
    return 'videos/$timestamp\_$cleanFileName';
  }

  String generateThumbnailPath(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFileName = sanitizeFileName(originalFileName);
    return 'thumbnails/$timestamp\_$cleanFileName';
  }

  String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9\._-]'), '_');
  }
}