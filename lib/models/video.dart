// lib/models/video.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/view_level.dart';

class Video {
  final String id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String userId;
  final String? userEmail;
  final DateTime createdAt;
  final int views;
  final String category;
  final int lastClaimedLevel;
  final List<String> claimedMilestones;
  final bool isProcessingClaim;
  final double totalEarnings;
  final DateTime? lastViewedAt;
  
  // New milestone-specific fields
  final Map<String, dynamic>? viewStats;
  final Map<String, dynamic>? reachMilestones;

  Video({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.userId,
    this.userEmail,
    required this.createdAt,
    this.views = 0,
    this.category = 'Videos',
    this.lastClaimedLevel = 0,
    this.claimedMilestones = const [],
    this.isProcessingClaim = false,
    this.totalEarnings = 0,
    this.lastViewedAt,
    this.viewStats,
    this.reachMilestones,
  });

  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      title: data['title'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      views: data['views'] ?? 0,
      category: data['category'] ?? 'Videos',
      lastClaimedLevel: data['lastClaimedLevel'] ?? 0,
      claimedMilestones: List<String>.from(data['claimedMilestones'] ?? []),
      isProcessingClaim: data['isProcessingClaim'] ?? false,
      totalEarnings: (data['totalEarnings'] ?? 0).toDouble(),
      lastViewedAt: data['lastViewedAt'] != null 
          ? (data['lastViewedAt'] as Timestamp).toDate() 
          : null,
      viewStats: data['viewStats'] as Map<String, dynamic>?,
      reachMilestones: data['reachMilestones'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'userId': userId,
      'userEmail': userEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'views': views,
      'category': category,
      'lastClaimedLevel': lastClaimedLevel,
      'claimedMilestones': claimedMilestones,
      'isProcessingClaim': isProcessingClaim,
      'totalEarnings': totalEarnings,
      if (lastViewedAt != null) 'lastViewedAt': Timestamp.fromDate(lastViewedAt!),
      if (viewStats != null) 'viewStats': viewStats,
      if (reachMilestones != null) 'reachMilestones': reachMilestones,
    };
  }

  // Milestone related helper methods
  bool isMilestoneClaimed(int level) {
    return claimedMilestones.contains(level.toString());
  }

  bool canClaimMilestone(int level) {
    return !isMilestoneClaimed(level) && 
           !isProcessingClaim && 
           level > lastClaimedLevel;
  }

  // View count formatting
  String getFormattedViews() {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M Views';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K Views';
    }
    return '$views Views';
  }

  // Time ago formatting
  String getTimeAgo() {
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
    } else {
      return 'Just now';
    }
  }

  // Next milestone calculation
  ViewLevel? getNextMilestone() {
    return ViewLevel.getNextLevel(views);
  }

  // Progress to next milestone
  int getProgressToNextMilestone() {
    return ViewLevel.getProgress(views);
  }

  // Total potential earnings
  double getPotentialEarnings() {
    return ViewLevel.getTotalPotentialEarnings(views);
  }

  // Remaining views to next milestone
  int getViewsToNextMilestone() {
    final nextLevel = getNextMilestone();
    if (nextLevel == null) return 0;
    return nextLevel.requiredViews - views;
  }

  // Create copy with updated fields
  Video copyWith({
    String? title,
    String? videoUrl,
    String? thumbnailUrl,
    String? userId,
    String? userEmail,
    DateTime? createdAt,
    int? views,
    String? category,
    int? lastClaimedLevel,
    List<String>? claimedMilestones,
    bool? isProcessingClaim,
    double? totalEarnings,
    DateTime? lastViewedAt,
    Map<String, dynamic>? viewStats,
    Map<String, dynamic>? reachMilestones,
  }) {
    return Video(
      id: id,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      createdAt: createdAt ?? this.createdAt,
      views: views ?? this.views,
      category: category ?? this.category,
      lastClaimedLevel: lastClaimedLevel ?? this.lastClaimedLevel,
      claimedMilestones: claimedMilestones ?? this.claimedMilestones,
      isProcessingClaim: isProcessingClaim ?? this.isProcessingClaim,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      viewStats: viewStats ?? this.viewStats,
      reachMilestones: reachMilestones ?? this.reachMilestones,
    );
  }

  // Analytics methods
  Map<String, dynamic> getViewTrends() {
    return viewStats ?? {};
  }

  List<DateTime> getMilestoneReachDates() {
    if (reachMilestones == null) return [];
    return reachMilestones!.entries
        .map((e) => (e.value as Timestamp).toDate())
        .toList();
  }

  // Check if video has reached any milestone
  bool hasReachedMilestone(int milestone) {
    return views >= milestone;
  }

  // Get highest reached milestone
  int getHighestReachedMilestone() {
    return ViewLevel.getCurrentLevel(views).requiredViews;
  }

  // Get earned amount
  double getEarnedAmount() {
    return claimedMilestones.fold(0.0, (sum, level) {
      final milestone = ViewLevel.levels[int.parse(level)];
      return sum + milestone.rewardAmount;
    });
  }

  // Get remaining claimable amount
  double getRemainingClaimableAmount() {
    double total = 0;
    for (var level in ViewLevel.levels) {
      if (views >= level.requiredViews && 
          !claimedMilestones.contains(level.level.toString()) &&
          level.level > lastClaimedLevel) {  // Add this check
        total += level.rewardAmount;
      }
    }
    return total;
  }
}