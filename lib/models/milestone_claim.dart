// lib/models/milestone_claim.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ClaimStatus {
  pending,    // Initial state when claim is submitted
  approved,   // Admin approved the claim
  rejected,   // Admin rejected the claim
  paid,       // Payment has been processed
  processing, // Payment is being processed
  failed      // Payment failed
}

class MilestoneClaim {
  final String id;
  final String videoId;
  final String userId;
  final String? userEmail;
  final int milestone;         // The milestone level claimed
  final int viewCount;         // Video views at time of claim
  final double amount;         // Reward amount
  final ClaimStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? processedAt;
  final DateTime? paidAt;
  final String? rejectionReason;
  final String? transactionId;
  final Map<String, dynamic>? paymentDetails;
  final Map<String, dynamic>? verificationData;

  MilestoneClaim({
    required this.id,
    required this.videoId,
    required this.userId,
    this.userEmail,
    required this.milestone,
    required this.viewCount,
    required this.amount,
    this.status = ClaimStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.processedAt,
    this.paidAt,
    this.rejectionReason,
    this.transactionId,
    this.paymentDetails,
    this.verificationData,
  });

  factory MilestoneClaim.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MilestoneClaim(
      id: doc.id,
      videoId: data['videoId'],
      userId: data['userId'],
      userEmail: data['userEmail'],
      milestone: data['milestone'],
      viewCount: data['viewCount'],
      amount: data['amount']?.toDouble() ?? 0.0,
      status: ClaimStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ClaimStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      processedAt: data['processedAt'] != null 
          ? (data['processedAt'] as Timestamp).toDate() 
          : null,
      paidAt: data['paidAt'] != null 
          ? (data['paidAt'] as Timestamp).toDate() 
          : null,
      rejectionReason: data['rejectionReason'],
      transactionId: data['transactionId'],
      paymentDetails: data['paymentDetails'],
      verificationData: data['verificationData'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'userId': userId,
      'userEmail': userEmail,
      'milestone': milestone,
      'viewCount': viewCount,
      'amount': amount,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (transactionId != null) 'transactionId': transactionId,
      if (paymentDetails != null) 'paymentDetails': paymentDetails,
      if (verificationData != null) 'verificationData': verificationData,
    };
  }

  String getStatusText() {
    switch (status) {
      case ClaimStatus.pending:
        return 'Pending Review';
      case ClaimStatus.approved:
        return 'Approved';
      case ClaimStatus.rejected:
        return 'Rejected';
      case ClaimStatus.paid:
        return 'Paid';
      case ClaimStatus.processing:
        return 'Processing Payment';
      case ClaimStatus.failed:
        return 'Payment Failed';
    }
  }

  Color getStatusColor() {
    switch (status) {
      case ClaimStatus.pending:
        return const Color(0xFFFFA726);  // Orange
      case ClaimStatus.approved:
        return const Color(0xFF66BB6A);  // Green
      case ClaimStatus.rejected:
        return const Color(0xFFEF5350);  // Red
      case ClaimStatus.paid:
        return const Color(0xFF26A69A);  // Teal
      case ClaimStatus.processing:
        return const Color(0xFF42A5F5);  // Blue
      case ClaimStatus.failed:
        return const Color(0xFFEF5350);  // Red
    }
  }

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

  String getFormattedAmount() {
    if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  bool canRetry() {
    return status == ClaimStatus.failed || 
           (status == ClaimStatus.rejected && 
            rejectionReason?.toLowerCase().contains('try again') == true);
  }

  bool isInProgress() {
    return status == ClaimStatus.pending || 
           status == ClaimStatus.processing;
  }

  bool isComplete() {
    return status == ClaimStatus.paid;
  }

  bool isFailed() {
    return status == ClaimStatus.failed || 
           status == ClaimStatus.rejected;
  }

  String? getPaymentMethod() {
    if (paymentDetails == null) return null;
    if (paymentDetails!['upiId'] != null) return 'UPI';
    if (paymentDetails!['bankAccount'] != null) return 'Bank Transfer';
    return null;
  }

  MilestoneClaim copyWith({
    String? videoId,
    String? userId,
    String? userEmail,
    int? milestone,
    int? viewCount,
    double? amount,
    ClaimStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? processedAt,
    DateTime? paidAt,
    String? rejectionReason,
    String? transactionId,
    Map<String, dynamic>? paymentDetails,
    Map<String, dynamic>? verificationData,
  }) {
    return MilestoneClaim(
      id: id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      milestone: milestone ?? this.milestone,
      viewCount: viewCount ?? this.viewCount,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processedAt: processedAt ?? this.processedAt,
      paidAt: paidAt ?? this.paidAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      transactionId: transactionId ?? this.transactionId,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      verificationData: verificationData ?? this.verificationData,
    );
  }
}