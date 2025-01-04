import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/video.dart';
import '../services/video_format_handler.dart';
import '../services/video_processor.dart';
import '../services/video_url_service.dart';
import 'r2_service.dart';

class StorageService {
  final R2Service _r2 = R2Service();
  final VideoUrlService _urlService = VideoUrlService();
  final VideoProcessor _videoProcessor = VideoProcessor();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const int maxVideoSize = 800 * 1024 * 1024; // 800MB
  static const int maxThumbnailSize = 5 * 1024 * 1024; // 5MB

  static const Map<String, String> videoFormats = {
    'mp4': 'video/mp4',
    'hls': 'application/x-mpegURL',
    'webm': 'video/webm',
    'mov': 'video/quicktime'
  };

  Future<void> uploadVideoWithMetadata({
    required String title,
    required Uint8List videoBytes,
    required String videoFileName,
    required Uint8List thumbnailBytes,
    required String thumbnailFileName,
    String quality = 'medium',
    bool generateHLS = false,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    String? videoId;
    Map<String, String> uploadUrls = {};

    try {
      _verifyUserPermissions();

      // Create initial document with processing status
      videoId = await _createInitialVideoDocument(title);
      onStatusUpdate?.call('Processing started...');

      // Process video for multiple formats
      final processedVideo = await _videoProcessor.processVideoForUpload(
        videoBytes,
        videoFileName,
        generateHLS: generateHLS || (!kIsWeb && Platform.isIOS),
        quality: quality,
        onProgress: (p) => onProgress?.call(p * 0.4),
      );

      onStatusUpdate?.call('Uploading files...');

      // Upload all formats
      uploadUrls = await _uploadAllFormats(
        videoId,
        processedVideo,
        onProgress: (p) => onProgress?.call(0.4 + (p * 0.4)),
      );

      // Upload thumbnail
      final thumbnailUrl = await _uploadThumbnail(
        thumbnailBytes,
        thumbnailFileName,
        onProgress: (p) => onProgress?.call(0.8 + (p * 0.1)),
      );

      // Save final metadata
      await _saveFinalMetadata(
        videoId: videoId,
        title: title,
        urls: uploadUrls,
        thumbnailUrl: thumbnailUrl,
        metadata: processedVideo['metadata'],
      );

      // Generate and save share URL
      await _generateShareUrl(videoId, uploadUrls);

      onProgress?.call(1.0);
      onStatusUpdate?.call('Upload complete!');

    } catch (e) {
      print('Upload error: $e');
      if (videoId != null) {
        await _handleUploadError(videoId, uploadUrls, e.toString());
      }
      throw Exception('Upload failed: $e');
    }
  }

  void _verifyUserPermissions() {
    if (_auth.currentUser == null) {
      throw Exception('User not authenticated');
    }
  }

  Future<String> _createInitialVideoDocument(String title) async {
    final doc = await _firestore.collection('videos').add({
      'title': title,
      'userId': _auth.currentUser?.uid,
      'userEmail': _auth.currentUser?.email,
      'createdAt': FieldValue.serverTimestamp(),
      'views': 0,
      'isProcessed': false,
      'processingStatus': 'Starting...',
    });
    return doc.id;
  }

  Future<Map<String, String>> _uploadAllFormats(
    String videoId,
    Map<String, dynamic> processedVideo, {
    Function(double)? onProgress,
  }) async {
    final results = <String, String>{};
    double progress = 0;
    final totalFormats = 2 + (processedVideo['hls'] != null ? 1 : 0);
    final progressIncrement = 1 / totalFormats;

    // Upload original
    results['original'] = await _r2.uploadBytes(
      processedVideo['original'],
      'videos/$videoId/original/video.mp4',
      videoFormats['mp4']!,
      onProgress: (p) {
        progress = p * progressIncrement;
        onProgress?.call(progress);
      },
    );

    // Upload web optimized version
    results['web_optimized'] = await _r2.uploadBytes(
      processedVideo['web_optimized'],
      'videos/$videoId/web/video.mp4',
      videoFormats['mp4']!,
      onProgress: (p) {
        progress = progressIncrement + (p * progressIncrement);
        onProgress?.call(progress);
      },
    );

    // Upload HLS if available
    if (processedVideo['hls'] != null) {
      await _uploadHLSFiles(
        videoId,
        processedVideo['hls'],
        (p) {
          progress = progressIncrement * 2 + (p * progressIncrement);
          onProgress?.call(progress);
        },
      );
      results['hls'] = 'videos/$videoId/hls/playlist.m3u8';
    }

    return results;
  }

  Future<void> _uploadHLSFiles(
    String videoId,
    Map<String, Uint8List> hlsFiles,
    Function(double) onProgress,
  ) async {
    int uploaded = 0;
    final total = hlsFiles.length;

    for (final entry in hlsFiles.entries) {
      await _r2.uploadBytes(
        entry.value,
        'videos/$videoId/hls/${entry.key}',
        videoFormats['hls']!,
      );
      uploaded++;
      onProgress(uploaded / total);
    }
  }

  Future<String> _uploadThumbnail(
    Uint8List thumbnailBytes,
    String fileName,
    {Function(double)? onProgress,
  }) async {
    return await _r2.uploadBytes(
      thumbnailBytes,
      'thumbnails/$fileName',
      'image/jpeg',
      onProgress: onProgress,
    );
  }

  Future<void> _saveFinalMetadata({
    required String videoId,
    required String title,
    required Map<String, String> urls,
    required String thumbnailUrl,
    required Map<String, dynamic> metadata,
  }) async {
    final playbackConfig = VideoFormatHandler.getPlaybackConfig(
      isIOS: !kIsWeb && Platform.isIOS,
      isWeb: kIsWeb,
      fileSize: metadata['filesize'] ?? 0,
    );

    await _firestore.collection('videos').doc(videoId).update({
      'title': title,
      'videoUrl': urls['web_optimized'],
      'originalUrl': urls['original'],
      'thumbnailUrl': thumbnailUrl,
      'hlsUrl': urls['hls'],
      'metadata': metadata,
      'isProcessed': true,
      'processingStatus': 'Complete',
      'primaryFormat': 'mp4',
      'hasHLSStream': urls['hls'] != null,
      'playbackConfig': playbackConfig,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _generateShareUrl(String videoId, Map<String, String> urls) async {
    final shareCode = await _urlService.getOrCreateShareCode(videoId);
    await _urlService.updateVideoFormat(
      shareCode,
      format: 'mp4',
      hasHLSStream: urls['hls'] != null,
    );
  }

  Future<void> _handleUploadError(
    String videoId,
    Map<String, String> uploadedUrls,
    String error,
  ) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'isProcessed': false,
        'processingStatus': 'Failed: $error',
      });

      for (final url in uploadedUrls.values) {
        await _r2.deleteFile(url).catchError((e) => print('Cleanup error: $e'));
      }
    } catch (e) {
      print('Error handling failed: $e');
    }
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      _verifyUserPermissions();

      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      final data = videoDoc.data();

      if (data == null) throw Exception('Video not found');
      if (data['userId'] != _auth.currentUser?.uid) {
        throw Exception('Not authorized to delete this video');
      }

      // Delete all video formats
      await Future.wait([
        if (data['originalUrl'] != null) _r2.deleteFile(data['originalUrl']),
        if (data['videoUrl'] != null) _r2.deleteFile(data['videoUrl']),
        if (data['hlsUrl'] != null) _r2.deleteFile(data['hlsUrl']),
        if (data['thumbnailUrl'] != null) _r2.deleteFile(data['thumbnailUrl']),
      ]);

      // Delete video document
      await videoDoc.reference.delete();

      // Delete share URLs
      await _deleteShareUrls(videoId);

    } catch (e) {
      print('Delete error: $e');
      throw Exception('Failed to delete video: $e');
    }
  }

  Future<void> _deleteShareUrls(String videoId) async {
    final urlDocs = await _firestore
        .collection('video_urls')
        .where('videoId', isEqualTo: videoId)
        .get();

    for (final doc in urlDocs.docs) {
      await doc.reference.delete();
    }
  }

  Future<List<Video>> getUserVideos() async {
    try {
      _verifyUserPermissions();

      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
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
      final batch = _firestore.batch();
      final videoRef = _firestore.collection('videos').doc(videoId);
      
      batch.update(videoRef, {
        'views': FieldValue.increment(1),
        'lastViewed': FieldValue.serverTimestamp(),
        'viewAnalytics': {
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'timestamp': FieldValue.serverTimestamp(),
          'viewerId': _auth.currentUser?.uid,
        }
      });

      await batch.commit();
    } catch (e) {
      print('View tracking error: $e');
    }
  }
}