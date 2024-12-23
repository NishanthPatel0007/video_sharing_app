import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class UploadService {
  static const String _workerUrl = 'https://your-worker.workers.dev';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getUploadUrl(String fileType) async {
    try {
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('$_workerUrl/getUploadUrl'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'fileType': fileType,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get upload URL: ${response.statusCode}');
      }

      return json.decode(response.body);
    } catch (e) {
      throw Exception('Failed to get upload URL: $e');
    }
  }

  Future<void> uploadWithProgress(
    Uint8List fileBytes,
    String uploadUrl,
    String contentType,
    Function(double) onProgress,
  ) async {
    try {
      final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl))
        ..headers['Content-Type'] = contentType
        ..headers['Content-Length'] = fileBytes.length.toString();

      var uploaded = 0;
      final stream = Stream.fromIterable(fileBytes.map((byte) => [byte]));
      await for (final chunk in stream) {
        request.sink.add(chunk);
        uploaded += chunk.length;
        onProgress(uploaded / fileBytes.length);
      }
      await request.sink.close();

      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  bool isValidFileType(String contentType, List<String> allowedTypes) {
    return allowedTypes.contains(contentType);
  }

  bool isValidFileSize(int size, int maxSize) {
    return size <= maxSize;
  }
}