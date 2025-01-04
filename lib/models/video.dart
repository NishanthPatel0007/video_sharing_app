import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class Video {
  final String id;
  final String title;
  final String userId;
  final String? userEmail;
  final String videoUrl;
  final String? originalUrl;
  final String thumbnailUrl;
  final DateTime createdAt;
  final int views;
  final String? hlsUrl;
  final Map<String, dynamic>? metadata;
  final bool isProcessed;
  final String? processingStatus;
  final String primaryFormat;
  final bool hasHLSStream;
  final Map<String, dynamic>? playbackConfig;
  final DateTime? lastViewed;
  final Map<String, dynamic>? viewAnalytics;

  Video({
    required this.id,
    required this.title,
    required this.userId,
    this.userEmail,
    required this.videoUrl,
    this.originalUrl,
    required this.thumbnailUrl,
    required this.createdAt,
    this.views = 0,
    this.hlsUrl,
    this.metadata,
    this.isProcessed = true,
    this.processingStatus,
    this.primaryFormat = 'mp4',
    this.hasHLSStream = false,
    this.playbackConfig,
    this.lastViewed,
    this.viewAnalytics,
  });

  bool isOwner() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid == userId;
  }

  String getPlaybackUrl() {
    if (hasHLSStream && hlsUrl != null && (!kIsWeb && Platform.isIOS)) {
      return hlsUrl!;
    }
    return videoUrl;
  }

  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Video(
      id: doc.id,
      title: data['title'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'],
      videoUrl: data['videoUrl'] ?? '',
      originalUrl: data['originalUrl'],
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      views: data['views'] ?? 0,
      hlsUrl: data['hlsUrl'],
      metadata: data['metadata'] as Map<String, dynamic>?,
      isProcessed: data['isProcessed'] ?? true,
      processingStatus: data['processingStatus'],
      primaryFormat: data['primaryFormat'] ?? 'mp4',
      hasHLSStream: data['hasHLSStream'] ?? false,
      playbackConfig: data['playbackConfig'] as Map<String, dynamic>?,
      lastViewed: data['lastViewed'] != null 
          ? (data['lastViewed'] as Timestamp).toDate() 
          : null,
      viewAnalytics: data['viewAnalytics'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'userId': userId,
      'userEmail': userEmail,
      'videoUrl': videoUrl,
      'originalUrl': originalUrl,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'views': views,
      'hlsUrl': hlsUrl,
      'metadata': metadata,
      'isProcessed': isProcessed,
      'processingStatus': processingStatus,
      'primaryFormat': primaryFormat,
      'hasHLSStream': hasHLSStream,
      'playbackConfig': playbackConfig,
      'lastViewed': lastViewed != null ? Timestamp.fromDate(lastViewed!) : null,
      'viewAnalytics': viewAnalytics,
    };
  }

  Video copyWith({
    String? title,
    String? userId,
    String? userEmail,
    String? videoUrl,
    String? originalUrl,
    String? thumbnailUrl,
    DateTime? createdAt,
    int? views,
    String? hlsUrl,
    Map<String, dynamic>? metadata,
    bool? isProcessed,
    String? processingStatus,
    String? primaryFormat,
    bool? hasHLSStream,
    Map<String, dynamic>? playbackConfig,
    DateTime? lastViewed,
    Map<String, dynamic>? viewAnalytics,
  }) {
    return Video(
      id: this.id,
      title: title ?? this.title,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      videoUrl: videoUrl ?? this.videoUrl,
      originalUrl: originalUrl ?? this.originalUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      views: views ?? this.views,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      metadata: metadata ?? this.metadata,
      isProcessed: isProcessed ?? this.isProcessed,
      processingStatus: processingStatus ?? this.processingStatus,
      primaryFormat: primaryFormat ?? this.primaryFormat,
      hasHLSStream: hasHLSStream ?? this.hasHLSStream,
      playbackConfig: playbackConfig ?? this.playbackConfig,
      lastViewed: lastViewed ?? this.lastViewed,
      viewAnalytics: viewAnalytics ?? this.viewAnalytics,
    );
  }

  String formatDuration() {
    if (metadata == null || !metadata!.containsKey('duration')) return '';
    
    final duration = Duration(seconds: metadata!['duration'].round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String formatViews() {
    if (views < 1000) return '$views views';
    if (views < 1000000) {
      return '${(views / 1000).toStringAsFixed(1)}K views';
    }
    return '${(views / 1000000).toStringAsFixed(1)}M views';
  }

  String formatUploadDate() {
    final difference = DateTime.now().difference(createdAt);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    }
    return 'Just now';
  }

  String getQualityInfo() {
    if (metadata == null || 
        !metadata!.containsKey('width') || 
        !metadata!.containsKey('height')) {
      return '';
    }
    
    final height = metadata!['height'] as int;
    if (height >= 2160) return '4K';
    if (height >= 1440) return '2K';
    if (height >= 1080) return 'FHD';
    if (height >= 720) return 'HD';
    return 'SD';
  }

  bool isProcessing() {
    return !isProcessed && processingStatus != null && 
           !processingStatus!.toLowerCase().contains('fail');
  }

  bool hasProcessingFailed() {
    return !isProcessed && processingStatus != null && 
           processingStatus!.toLowerCase().contains('fail');
  }

  String getCurrentFormat() {
    if (hasHLSStream && (!kIsWeb && Platform.isIOS)) {
      return 'hls';
    }
    return primaryFormat;
  }

  Duration getTotalWatchTime() {
    if (viewAnalytics == null || !viewAnalytics!.containsKey('totalDuration')) {
      return Duration.zero;
    }
    return Duration(seconds: viewAnalytics!['totalDuration']);
  }
}