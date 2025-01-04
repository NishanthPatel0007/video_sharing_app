import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class R2Service {
  // Base URLs and configuration
  final String workerUrl = 'https://r2.for10cloud.com';
  final String publicUrl = 'https://r2.for10cloud.com';
  final String bucketName = 'cloudfarebuckey2002';
  final String accountId = '666bfc1258e239123f4ced095cb958e4';

  // Storage paths
  static const String videoPath = 'videos';
  static const String hlsPath = 'hls';
  static const String thumbnailPath = 'thumbnails';
  static const String tempPath = 'temp';
  static const String chunkPath = 'chunks';

  // File size thresholds
  static const int smallFileLimit = 20 * 1024 * 1024;    // 20MB
  static const int mediumFileLimit = 80 * 1024 * 1024;   // 80MB
  static const int largeFileLimit = 200 * 1024 * 1024;   // 200MB
  static const int ultraLargeFileLimit = 400 * 1024 * 1024; // 400MB

  // Maximum file sizes
  static const int maxVideoSize = 500 * 1024 * 1024;     // 500MB
  static const int maxThumbnailSize = 5 * 1024 * 1024;   // 5MB

  // Allowed file types
  static final List<String> allowedVideoTypes = [
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska',
    'video/webm',
    'application/x-mpegURL'
  ];

  static final List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/webp'
  ];

  // Get timeout duration based on file size
  Duration getTimeout(int fileSize) {
    if (fileSize <= smallFileLimit) return const Duration(minutes: 2);
    if (fileSize <= mediumFileLimit) return const Duration(minutes: 5);
    if (fileSize <= largeFileLimit) return const Duration(minutes: 10);
    return const Duration(minutes: 15);
  }

  // Get chunk size based on file size
  int getChunkSize(int fileSize) {
    if (fileSize <= smallFileLimit) return 2 * 1024 * 1024;  // 2MB
    if (fileSize <= mediumFileLimit) return 4 * 1024 * 1024; // 4MB
    if (fileSize <= largeFileLimit) return 8 * 1024 * 1024;  // 8MB
    return 10 * 1024 * 1024; // 10MB
  }

  // Get number of concurrent uploads
  int getConcurrentUploads(int fileSize) {
    if (fileSize <= smallFileLimit) return 3;
    if (fileSize <= mediumFileLimit) return 2;
    return 1;
  }

  // Upload with multiple format support
  Future<Map<String, String>> uploadMultiFormat({
    required String videoId,
    required Uint8List originalBytes,
    required Uint8List webOptimizedBytes,
    Map<String, Uint8List>? hlsFiles,
    required String contentType,
    Function(double)? onProgress,
  }) async {
    final results = <String, String>{};
    double progress = 0;
    
    try {
      // Upload original
      final originalPath = '$videoPath/$videoId/original/video${_getExtension(contentType)}';
      results['original'] = await uploadBytes(
        originalBytes,
        originalPath,
        contentType,
        onProgress: (p) {
          progress = p * 0.4;
          onProgress?.call(progress);
        }
      );

      // Upload web optimized version
      final webOptPath = '$videoPath/$videoId/web_optimized/video.mp4';
      results['web_optimized'] = await uploadBytes(
        webOptimizedBytes,
        webOptPath,
        'video/mp4',
        onProgress: (p) {
          progress = 0.4 + (p * 0.4);
          onProgress?.call(progress);
        }
      );

      // Upload HLS files if present
      if (hlsFiles != null) {
        double hlsProgress = 0;
        final hlsBasePath = '$videoPath/$videoId/hls';
        
        await Future.wait(
          hlsFiles.entries.map((entry) async {
            final hlsPath = '$hlsBasePath/${entry.key}';
            final url = await uploadBytes(
              entry.value,
              hlsPath,
              'application/x-mpegURL',
              onProgress: (p) {
                hlsProgress += p / hlsFiles.length;
                progress = 0.8 + (hlsProgress * 0.2);
                onProgress?.call(progress);
              }
            );
            if (entry.key == 'master.m3u8') {
              results['hls'] = url;
            }
          })
        );
      }

      return results;
    } catch (e) {
      print('Upload error: $e');
      await _cleanupFailedUpload(videoId);
      throw Exception('Upload failed: $e');
    }
  }

  // Upload single file with chunking support
  Future<String> uploadBytes(
    Uint8List bytes,
    String fileName,
    String contentType, {
    Function(double)? onProgress,
  }) async {
    try {
      final fileSize = bytes.length;
      print('Starting upload of ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB file');

      // Verify file size
      final maxSize = contentType.startsWith('video/') ? maxVideoSize : maxThumbnailSize;
      if (fileSize > maxSize) {
        throw Exception('File size exceeds the maximum limit');
      }

      // Verify file type
      if (!isValidFileType(contentType, allowedTypes(contentType))) {
        throw Exception('Invalid file type: $contentType');
      }

      // Choose upload method based on size
      if (fileSize <= 5 * 1024 * 1024) {
        return _uploadSmallFile(bytes, fileName, contentType, onProgress);
      }

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

  // Upload small file directly
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

  // Upload large file in chunks
  Future<String> _uploadLargeFile(
    Uint8List bytes,
    String fileName,
    String contentType,
    int chunkSize,
    int maxConcurrent,
    Duration timeout,
    Function(double)? onProgress,
  ) async {
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 10);
    
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
    final totalChunks = (bytes.length / chunkSize).ceil();
    var completedChunks = 0;
    final failedChunks = <int>{};

    print('\nUpload configuration:');
    print('File size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB');
    print('Chunk size: ${(chunkSize / 1024 / 1024).toStringAsFixed(2)}MB');
    print('Total chunks: $totalChunks');
    print('Concurrent uploads: $maxConcurrent\n');

    final clients = List.generate(maxConcurrent, (_) => http.Client());

    try {
      for (var attempt = 0; attempt < maxRetries; attempt++) {
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
            await Future.delayed(retryDelay * (attempt + 1));
            break;
          } else {
            throw Exception('Failed to upload chunks after multiple retries');
          }
        }

        if (failedChunks.isEmpty) break;
      }

      return '$publicUrl/$fileName';
    } finally {
      for (final client in clients) {
        client.close();
      }
    }
  }

  // Upload single chunk
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

  // Delete file and related versions
  Future<void> deleteFile(String fileUrl) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments.join('/');
      
      final deleteUri = Uri.parse('$workerUrl/$filePath');

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

  // Clean up failed upload
  Future<void> _cleanupFailedUpload(String videoId) async {
    try {
      final paths = [
        '$videoPath/$videoId/original',
        '$videoPath/$videoId/web_optimized',
        '$videoPath/$videoId/hls',
        '$chunkPath/$videoId',
      ];

      for (final path in paths) {
        await deleteFile('$workerUrl/$path/*').catchError((e) => print('Cleanup error: $e'));
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  // Get file extension from content type
  String _getExtension(String contentType) {
    switch (contentType) {
      case 'video/mp4': return '.mp4';
      case 'video/webm': return '.webm';
      case 'video/quicktime': return '.mov';
      case 'video/x-msvideo': return '.avi';
      case 'video/x-matroska': return '.mkv';
      default: return '.mp4';
    }
  }

  // Get allowed types based on content type
  List<String> allowedTypes(String contentType) {
    return contentType.startsWith('video/') ? allowedVideoTypes : allowedImageTypes;
  }

  // Validate file type
  bool isValidFileType(String contentType, List<String> allowedTypes) {
    return allowedTypes.contains(contentType.toLowerCase());
  }

  // Generate video storage path
  String generateVideoPath(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFileName = sanitizeFileName(originalFileName);
    return 'videos/$timestamp\_$cleanFileName';
  }

  // Generate thumbnail storage path
  String generateThumbnailPath(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanFileName = sanitizeFileName(originalFileName);
    return 'thumbnails/$timestamp\_$cleanFileName';
  }

  // Sanitize file name
  String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9\._-]'), '_');
  }
}