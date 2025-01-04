import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class UploadService {
  static const String _baseUrl = 'https://r2.for10cloud.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Size limits
  static const int maxVideoSize = 500 * 1024 * 1024; // 500MB
  static const int maxThumbnailSize = 5 * 1024 * 1024; // 5MB
  static const int chunkSize = 5 * 1024 * 1024; // 5MB chunks

  // Supported formats
  static const List<String> supportedVideoFormats = [
    'video/mp4',
    'video/quicktime',
    'video/webm',
    'application/x-mpegURL'
  ];

  static const List<String> supportedImageFormats = [
    'image/jpeg',
    'image/png',
    'image/webp'
  ];

  // Upload file with chunking support
  Future<String> uploadFile(
    Uint8List fileBytes,
    String fileName,
    String contentType, {
    Function(double)? onProgress,
  }) async {
    try {
      // Validate file
      _validateFile(fileBytes, contentType);

      // Get auth token
      final token = await _auth.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      // For small files, upload directly
      if (fileBytes.length <= chunkSize) {
        return await _uploadSmallFile(
          fileBytes, 
          fileName, 
          contentType,
          token,
          onProgress,
        );
      }

      // For large files, use chunked upload
      return await _uploadLargeFile(
        fileBytes,
        fileName,
        contentType,
        token,
        onProgress,
      );

    } catch (e) {
      print('Upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }

  // Upload small file directly
  Future<String> _uploadSmallFile(
    Uint8List fileBytes,
    String fileName,
    String contentType,
    String token,
    Function(double)? onProgress,
  ) async {
    final url = '$_baseUrl/$fileName';
    final uri = Uri.parse(url);

    final request = http.Request('PUT', uri)
      ..headers.addAll({
        'Content-Type': contentType,
        'Authorization': 'Bearer $token',
        'Content-Length': fileBytes.length.toString(),
      })
      ..bodyBytes = fileBytes;

    final response = await request.send();
    
    if (response.statusCode == 200) {
      onProgress?.call(1.0);
      return url;
    }
    
    throw Exception('Upload failed with status: ${response.statusCode}');
  }

  // Upload large file in chunks
  Future<String> _uploadLargeFile(
    Uint8List fileBytes,
    String fileName,
    String contentType,
    String token,
    Function(double)? onProgress,
  ) async {
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
    final totalChunks = (fileBytes.length / chunkSize).ceil();
    var uploadedChunks = 0;

    try {
      for (var i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (i + 1) * chunkSize;
        final chunk = fileBytes.sublist(
          start,
          end > fileBytes.length ? fileBytes.length : end,
        );

        await _uploadChunk(
          chunk,
          fileName,
          contentType,
          token,
          uploadId,
          i,
          totalChunks,
        );

        uploadedChunks++;
        onProgress?.call(uploadedChunks / totalChunks);
      }

      final finalizeUrl = '$_baseUrl/$fileName?uploadId=$uploadId';
      final finalizeResponse = await http.post(
        Uri.parse(finalizeUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (finalizeResponse.statusCode != 200) {
        throw Exception('Failed to finalize upload');
      }

      return '$_baseUrl/$fileName';

    } catch (e) {
      await _abortUpload(fileName, uploadId, token);
      throw Exception('Chunked upload failed: $e');
    }
  }

  // Upload single chunk
  Future<void> _uploadChunk(
    Uint8List chunk,
    String fileName,
    String contentType,
    String token,
    String uploadId,
    int partNumber,
    int totalParts,
  ) async {
    final url = '$_baseUrl/$fileName?partNumber=$partNumber&uploadId=$uploadId';
    final uri = Uri.parse(url);

    final request = http.Request('PUT', uri)
      ..headers.addAll({
        'Content-Type': contentType,
        'Authorization': 'Bearer $token',
        'X-Upload-Id': uploadId,
        'X-Part-Number': partNumber.toString(),
        'X-Total-Parts': totalParts.toString(),
      })
      ..bodyBytes = chunk;

    final response = await request.send();
    
    if (response.statusCode != 200) {
      throw Exception('Chunk upload failed: ${response.statusCode}');
    }
  }

  // Abort multipart upload
  Future<void> _abortUpload(
    String fileName,
    String uploadId,
    String token,
  ) async {
    try {
      final url = '$_baseUrl/$fileName?uploadId=$uploadId';
      await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      print('Abort upload error: $e');
    }
  }

  // Validate file
  void _validateFile(Uint8List fileBytes, String contentType) {
    // Check file size
    final maxSize = contentType.startsWith('video/') 
        ? maxVideoSize 
        : maxThumbnailSize;
    
    if (fileBytes.length > maxSize) {
      throw Exception(
        'File size exceeds the maximum limit of ${maxSize ~/ (1024 * 1024)}MB'
      );
    }

    // Check format
    final validFormats = contentType.startsWith('video/') 
        ? supportedVideoFormats 
        : supportedImageFormats;
    
    if (!validFormats.contains(contentType.toLowerCase())) {
      throw Exception('Unsupported file format: $contentType');
    }
  }

  // Delete file
  Future<void> deleteFile(String fileUrl) async {
    try {
      final token = await _auth.currentUser?.getIdToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.delete(
        Uri.parse(fileUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Delete error: $e');
      throw Exception('Failed to delete file: $e');
    }
  }
}