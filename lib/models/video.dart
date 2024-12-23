import 'package:cloud_firestore/cloud_firestore.dart';

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

  Video({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.userId,
    this.userEmail,
    required this.createdAt,
    this.views = 0,
    this.category = 'Videos'
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
    };
  }
}