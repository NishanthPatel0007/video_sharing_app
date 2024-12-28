import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class R2Service {
  final String workerUrl = 'https://r2.for10cloud.com';
  final String publicUrl = 'https://r2.for10cloud.com';
  final String bucketName = 'cloudfarebuckey2002';

  // File size thresholds
  static const int smallFileLimit = 20 * 1024 * 1024;    // 20MB
  static const int mediumFileLimit = 80 * 1024 * 1024;   // 80MB
  static const int largeFileLimit = 200 * 1024 * 1024;   // 200MB
  static const int ultraLargeFileLimit = 400 * 1024 * 1024; // 400MB

  // Maximum file sizes
  static const int maxVideoSize = 500 * 1024 * 1024;     // 500MB for web
  static const int maxMobileVideoSize = 200 * 1024 * 1024; // 200MB for mobile
  static const int maxThumbnailSize = 5 * 1024 * 1024;   // 5MB

  // Retry settings
  static const int maxRetries = 5;
  static const Duration retryDelay = Duration(seconds: 10);

  // Allowed file types
  static final List<String> _allowedVideoTypes = [
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska'
  ];

  static final List<String> _allowedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/jpg'
  ];

  Duration getTimeout(int fileSize) {
    if (fileSize <= smallFileLimit) return const Duration(minutes: 2);
    if (fileSize <= mediumFileLimit) return const Duration(minutes: 5);
    if (fileSize <= largeFileLimit) return const Duration(minutes: 10);
    return const Duration(minutes: 15);
  }

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

  int getConcurrentUploads(int fileSize, bool isMobile) {
    if (isMobile) {
      return fileSize <= mediumFileLimit ? 2 : 1;
    }
    if (fileSize <= smallFileLimit) return 3;
    if (fileSize <= mediumFileLimit) return 2;
    return 1;
  }

  Future<String> uploadBytes(
    Uint8List bytes,
    String fileName,
    String contentType, {
    Function(double)? onProgress,
    bool isMobile = false,
  }) async {
    try {
      final fileSize = bytes.length;
      print('Starting upload of ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB file');

      // Validate file type
      final allowedTypes = contentType.startsWith('video/') 
          ? _allowedVideoTypes 
          : _allowedImageTypes;
          
      if (!isValidFileType(contentType, allowedTypes)) {
        throw Exception('Invalid file type: $contentType');
      }

      // Check file size limits
      final maxSize = contentType.startsWith('video/') 
          ? (isMobile ? maxMobileVideoSize : maxVideoSize) 
          : maxThumbnailSize;
          
      if (fileSize > maxSize) {
        throw Exception('File size exceeds ${maxSize ~/ (1024 * 1024)}MB limit');
      }

      // Use fast path for small files
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
    final clients = List.generate(maxConcurrent, (_) => http.Client());

    try {
      onProgress?.call(0.01);  // Initial progress

      // Retry logic for failed chunks
      for (var attempt = 0; attempt < maxRetries; attempt++) {
        if (attempt > 0) {
          print('Attempt ${attempt + 1} of $maxRetries');
          onProgress?.call(completedChunks / totalChunks);
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
                print('Chunk $chunkIndex failed: $e');
                failedChunks.add(chunkIndex);
              })
            );
          }

          await Future.wait(batch);
          
          // Handle failed chunks
          if (failedChunks.isEmpty) {
            i += batchSize;
          } else if (attempt < maxRetries - 1) {
            final delay = retryDelay * (attempt + 1);
            print('Retrying failed chunks after ${delay.inSeconds}s delay...');
            await Future.delayed(delay);
            break;
          } else {
            throw Exception('Failed to upload chunks after $maxRetries attempts');
          }
        }

        if (failedChunks.isEmpty) break;
      }

      // Combine chunks if needed
      await _combineChunks(
        fileName,
        uploadId,
        contentType,
        totalChunks,
        bytes.length,
      );

      print('Upload completed successfully');
      return '$publicUrl/$fileName';
    } finally {
      // Cleanup
      for (final client in clients) {
        client.close();
      }
    }
  }

  Future<void> _combineChunks(
    String fileName,
    String uploadId,
    String contentType,
    int totalChunks,
    int totalSize,
  ) async {
    final response = await http.post(
      Uri.parse('$workerUrl/combine'),
      headers: {
        'Content-Type': 'application/json',
        'X-Upload-Id': uploadId,
        'X-File-Name': fileName,
        'X-Content-Type': contentType,
        'X-Total-Chunks': totalChunks.toString(),
        'X-Total-Size': totalSize.toString(),
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to combine chunks: ${response.statusCode}');
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

  Future<void> deleteFile(String url) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(url);
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