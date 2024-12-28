// lib/services/storage_service.dart
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/milestone_claim.dart';
import '../models/payment_details.dart';
import '../models/video.dart';
import '../models/view_level.dart';
import '../services/r2_service.dart';
import '../services/video_url_service.dart';

class StorageService {
  final R2Service _r2 = R2Service();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final VideoUrlService _urlService = VideoUrlService();

  // File size limits
  static const int maxVideoSize = 500 * 1024 * 1024;    // 500MB for web
  static const int maxMobileVideoSize = 200 * 1024 * 1024; // 200MB for mobile
  static const int maxThumbnailSize = 5 * 1024 * 1024;  // 5MB

  // Upload retry settings
  static const int maxUploadRetries = 3;
  static const Duration retryDelay = Duration(seconds: 5);

  Future<void> uploadVideoWithMetadata({
    required String title,
    required Uint8List videoBytes,
    required String videoFileName,
    required Uint8List thumbnailBytes,
    required String thumbnailFileName,
    Function(double)? onProgress,
    bool isMobile = false,
  }) async {
    String? videoUrl;
    String? thumbnailUrl;
    double videoProgress = 0;

    try {
      // Validate file sizes based on platform
      final maxSize = isMobile ? maxMobileVideoSize : maxVideoSize;
      if (videoBytes.length > maxSize) {
        throw Exception(
          'Video file must be less than ${maxSize ~/ (1024 * 1024)}MB ${isMobile ? 'on mobile' : ''}'
        );
      }

      if (thumbnailBytes.length > maxThumbnailSize) {
        throw Exception('Thumbnail must be less than 5MB');
      }

      // Upload thumbnail first
      thumbnailUrl = await uploadToR2(
        thumbnailBytes,
        'thumbnails/$thumbnailFileName',
        'image/jpeg',
        onProgress: (p) => onProgress?.call(p * 0.2),
        isMobile: isMobile,
      );

      if (thumbnailUrl != null && !thumbnailUrl.startsWith('https://')) {
        throw Exception('Invalid thumbnail upload response');
      }

      // Then upload video with retry logic
      videoUrl = await _retryUpload(
        () => uploadToR2(
          videoBytes,
          'videos/$videoFileName',
          'video/mp4',
          onProgress: (p) {
            videoProgress = p;
            onProgress?.call(0.2 + (p * 0.7));
          },
          isMobile: isMobile,
        ),
      );

      if (videoUrl != null && !videoUrl.startsWith('https://')) {
        throw Exception('Invalid video upload response');
      }

      if (videoProgress == 1.0 && thumbnailUrl?.isNotEmpty == true && videoUrl?.isNotEmpty == true) {
        await saveVideoMetadata(
          title: title,
          videoUrl: videoUrl!,
          thumbnailUrl: thumbnailUrl!,
        );
        onProgress?.call(1.0);
      } else {
        // Clean up partial uploads
        if (thumbnailUrl?.isNotEmpty == true) await _r2.deleteFile(thumbnailUrl!);
        if (videoUrl?.isNotEmpty == true) await _r2.deleteFile(videoUrl!);
        throw Exception('Upload incomplete');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      // Clean up on error
      if (thumbnailUrl?.isNotEmpty == true) await _r2.deleteFile(thumbnailUrl!);
      if (videoUrl?.isNotEmpty == true) await _r2.deleteFile(videoUrl!);
      throw Exception('Upload failed: $e');
    }
  }

  Future<T> _retryUpload<T>(
    Future<T> Function() uploadFunc, 
    {int maxAttempts = maxUploadRetries}
  ) async {
    Exception? lastError;
    for (int i = 0; i < maxAttempts; i++) {
      try {
        return await uploadFunc();
      } catch (e) {
        lastError = e as Exception;
        if (i == maxAttempts - 1) break;
        await Future.delayed(retryDelay * (i + 1));
      }
    }
    throw lastError ?? Exception('Upload failed after $maxAttempts attempts');
  }

  Future<String> uploadToR2(
    Uint8List fileBytes, 
    String fileName, 
    String contentType, {
    Function(double)? onProgress,
    bool isMobile = false,
  }) async {
    try {
      final url = await _r2.uploadBytes(
        fileBytes,
        fileName,
        contentType,
        onProgress: onProgress,
        isMobile: isMobile,
      );

      debugPrint('Upload successful. URL: $url');
      return url;
    } catch (e) {
      debugPrint('Storage service upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }

  Future<String> saveVideoMetadata({
    required String title,
    required String videoUrl,
    required String thumbnailUrl,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      // Save to videos collection
      final docRef = await _firestore.collection('videos').add({
        'title': title,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'userId': userId,
        'userEmail': _auth.currentUser?.email,
        'views': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastClaimedLevel': 0,
        'claimedMilestones': [],
        'isProcessingClaim': false,
        'totalEarnings': 0,
        'viewStats': {
          'daily': {},
          'weekly': {},
          'monthly': {},
        },
        'reachMilestones': {},
        'platform': {
          'userAgent': kIsWeb ? html.window.navigator.userAgent : 'Flutter',
          'isWeb': kIsWeb,
        }
      });

      // Generate share code
      final shareCode = await _urlService.getOrCreateShareCode(docRef.id);
      return 'for10cloud.com/v/$shareCode';
    } catch (e) {
      debugPrint('Save metadata error: $e');
      throw Exception('Failed to save video metadata: $e');
    }
  }

  Future<PaymentDetails?> getPaymentDetails() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore
          .collection('payment_details')
          .doc(userId)
          .get();

      if (!doc.exists) return null;
      return PaymentDetails.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting payment details: $e');
      return null;
    }
  }

  Future<void> processMilestoneClaim({
    required String videoId,
    required int level,
    required double amount,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      final batch = _firestore.batch();
      final videoRef = _firestore.collection('videos').doc(videoId);
      
      // Verify video ownership and claim eligibility
      final videoDoc = await videoRef.get();
      if (!videoDoc.exists) throw Exception('Video not found');
      
      final videoData = videoDoc.data()!;
      if (videoData['userId'] != userId) {
        throw Exception('Not authorized to claim milestone');
      }

      if ((videoData['lastClaimedLevel'] as int? ?? 0) >= level) {
        throw Exception('Milestone already claimed');
      }

      final currentViews = videoData['views'] as int? ?? 0;
      if (currentViews < ViewLevel.levels[level].requiredViews) {
        throw Exception('Milestone not reached yet');
      }

      // Update video milestone status
      batch.update(videoRef, {
        'lastClaimedLevel': level,
        'claimedMilestones': FieldValue.arrayUnion([level.toString()]),
        'totalEarnings': FieldValue.increment(amount),
      });

      // Create milestone claim record
      final claimRef = _firestore.collection('milestone_claims').doc();
      batch.set(claimRef, {
        'videoId': videoId,
        'userId': userId,
        'userEmail': _auth.currentUser?.email,
        'level': level,
        'amount': amount,
        'status': ClaimStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'viewCount': currentViews,
        'viewStats': videoData['viewStats'],
        'verificationData': {
          'milestoneReachedAt': videoData['reachMilestones']?[level.toString()],
          'platform': videoData['platform'],
        }
      });

      // Update user total earnings
      batch.update(
        _firestore.collection('users').doc(userId),
        {
          'totalPendingClaims': FieldValue.increment(1),
          'totalPendingAmount': FieldValue.increment(amount),
        },
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Process milestone claim error: $e');
      throw Exception('Failed to process milestone claim: $e');
    }
  }

  Future<List<Video>> getUserVideos() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      final snapshot = await _firestore.collection('videos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Get videos error: $e');
      throw Exception('Failed to fetch videos: $e');
    }
  }

  Future<void> incrementViews(String videoId) async {
    try {
      final batch = _firestore.batch();
      final videoRef = _firestore.collection('videos').doc(videoId);
      
      // Update views and stats
      batch.update(videoRef, {
        'views': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
        'viewStats.daily.${_getDayKey()}': FieldValue.increment(1),
        'viewStats.weekly.${_getWeekKey()}': FieldValue.increment(1),
        'viewStats.monthly.${_getMonthKey()}': FieldValue.increment(1),
      });

      // Check for milestone achievement
      final videoDoc = await videoRef.get();
      final currentViews = videoDoc.data()?['views'] as int? ?? 0;
      
      for (var level in ViewLevel.levels) {
        if (currentViews < level.requiredViews && 
            currentViews + 1 >= level.requiredViews) {
          batch.update(videoRef, {
            'reachMilestones.${level.level}': FieldValue.serverTimestamp(),
          });
          break;
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Increment views error: $e');
    }
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      if (!videoDoc.exists) throw Exception('Video not found');

      final data = videoDoc.data();
      if (data == null) throw Exception('Invalid video data');

      final videoUrl = data['videoUrl'] as String?;
      final thumbnailUrl = data['thumbnailUrl'] as String?;

      // Delete files from R2
      if (videoUrl?.isNotEmpty == true) {
        await _r2.deleteFile(videoUrl!);
      }
      if (thumbnailUrl?.isNotEmpty == true) {
        await _r2.deleteFile(thumbnailUrl!);
      }

      final batch = _firestore.batch();

      // Delete video document
      batch.delete(videoDoc.reference);

      // Delete share codes
      final shareCodes = await _firestore.collection('video_urls')
          .where('videoId', isEqualTo: videoId)
          .get();
      
      for (var doc in shareCodes.docs) {
        batch.delete(doc.reference);
      }

      // Delete milestone claims
      final claims = await _firestore.collection('milestone_claims')
          .where('videoId', isEqualTo: videoId)
          .where('status', isEqualTo: ClaimStatus.pending.name)
          .get();

      for (var doc in claims.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Delete video error: $e');
      throw Exception('Failed to delete video: $e');
    }
  }

  // Helper methods for view stats
  String _getDayKey() => DateTime.now().toIso8601String().substring(0, 10);
  
  String _getWeekKey() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return startOfWeek.toIso8601String().substring(0, 10);
  }
  
  String _getMonthKey() => DateTime.now().toIso8601String().substring(0, 7);
}