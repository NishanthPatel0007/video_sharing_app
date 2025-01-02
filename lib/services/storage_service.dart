import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/video.dart';
import 'r2_service.dart';

class StorageService {
  final R2Service _r2 = R2Service();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const int maxVideoSize = 800 * 1024 * 1024;  // 800MB
  static const int maxThumbnailSize = 5 * 1024 * 1024;  // 5MB

  Future<void> uploadVideoWithMetadata({
    required String title,
    required Uint8List videoBytes,
    required String videoFileName,
    required Uint8List thumbnailBytes,
    required String thumbnailFileName,
    Function(double)? onProgress,
  }) async {
    String? videoUrl;
    String? thumbnailUrl;
    double videoProgress = 0;

    try {
      // Upload thumbnail first
      thumbnailUrl = await _r2.uploadBytes(
        thumbnailBytes,
        'thumbnails/$thumbnailFileName',
        'image/jpeg',
        onProgress: (p) => onProgress?.call(p * 0.2),
      );

      // Then upload video
      videoUrl = await _r2.uploadBytes(
        videoBytes,
        'videos/$videoFileName',
        'video/mp4',
        onProgress: (p) {
          videoProgress = p;
          onProgress?.call(0.2 + (p * 0.7));
        },
      );

      // Only save to Firebase if both uploads are successful
      if (videoProgress == 1.0 && thumbnailUrl != null && videoUrl != null) {
        await saveVideoMetadata(
          title: title,
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
        );
        onProgress?.call(1.0);
      } else {
        // Clean up partial uploads
        if (thumbnailUrl != null) {
          await _r2.deleteFile(thumbnailUrl);
        }
        if (videoUrl != null) {
          await _r2.deleteFile(videoUrl);
        }
        throw Exception('Upload incomplete');
      }
    } catch (e) {
      // Clean up on error
      if (thumbnailUrl != null) {
        await _r2.deleteFile(thumbnailUrl);
      }
      if (videoUrl != null) {
        await _r2.deleteFile(videoUrl);
      }
      print('Upload failed: $e');
      throw Exception('Upload failed: $e');
    }
  }

  Future<String> uploadToR2(Uint8List fileBytes, String fileName, String contentType, 
      {Function(double)? onProgress}) async {
    try {
      final maxSize = contentType.startsWith('video/') ? maxVideoSize : maxThumbnailSize;
      if (fileBytes.length > maxSize) {
        throw Exception('File size exceeds ${maxSize ~/ (1024 * 1024)}MB limit');
      }

      final url = await _r2.uploadBytes(
        fileBytes,
        fileName,
        contentType,
        onProgress: onProgress
      );

      print('Upload successful. URL: $url');
      return url;
    } catch (e) {
      print('Storage service upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }

  Future<void> saveVideoMetadata({
    required String title,
    required String videoUrl,
    required String thumbnailUrl,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore.collection('videos').add({
        'title': title,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'userId': userId,
        'userEmail': _auth.currentUser?.email,
        'views': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Save metadata error: $e');
      throw Exception('Failed to save video metadata: $e');
    }
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      print('Attempting to delete video: $videoId');

      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      final videoData = videoDoc.data();

      if (videoData == null) throw Exception('Video not found');
      if (videoData['userId'] != userId) throw Exception('Not authorized to delete this video');

      // Delete files from R2 first
      print('Deleting video file...');
      await _r2.deleteFile(videoData['videoUrl']);
      
      print('Deleting thumbnail file...');
      await _r2.deleteFile(videoData['thumbnailUrl']);

      // Then delete metadata
      print('Deleting metadata...');
      await _firestore.collection('videos').doc(videoId).delete();

      print('Video deletion completed successfully');
    } catch (e) {
      print('Delete video error: $e');
      throw Exception('Failed to delete video: $e');
    }
  }

  Future<List<Video>> getUserVideos() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore.collection('videos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    } catch (e) {
      print('Get videos error: $e');
      throw Exception('Failed to fetch videos: $e');
    }
  }

  Future<void> incrementViews(String videoId) async {
    try {
      await _firestore.collection('videos')
          .doc(videoId)
          .update({
            'views': FieldValue.increment(1)
          });
    } catch (e) {
      print('Increment views error: $e');
    }
  }

  bool isValidFile(int fileSize, String contentType) {
    final maxSize = contentType.startsWith('video/') ? maxVideoSize : maxThumbnailSize;
    return fileSize <= maxSize;
  }
}