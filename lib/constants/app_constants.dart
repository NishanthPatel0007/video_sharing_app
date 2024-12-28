// lib/constants/app_constants.dart
import 'package:flutter/material.dart';

class AppConstants {
  // API & Endpoints
  static const String apiBaseUrl = 'https://r2.for10cloud.com';
  static const String baseUrl = 'https://for10cloud.com';
  
  // File Constraints
  static const int maxVideoSize = 500 * 1024 * 1024;     // 500MB for web
  static const int maxMobileVideoSize = 200 * 1024 * 1024; // 200MB for mobile
  static const int maxThumbnailSize = 5 * 1024 * 1024;   // 5MB
  
  // Supported Formats
  static const List<String> supportedVideoFormats = [
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska',
    'video/mov',
    'video/m4v',
    'video/mpeg',
    'video/webm'
  ];
  
  static const List<String> supportedImageFormats = [
    'image/jpeg',
    'image/png',
    'image/jpg',
    'image/webp'
  ];

  // Theme Colors
  static const Color primaryColor = Color(0xFF8257E5);
  static const Color backgroundColor = Color(0xFF1E1B2C);
  static const Color cardColor = Color(0xFF2D2940);
  static const Color accentColor = Color(0xFF633BBC);
  
  // Typography
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: Colors.white70,
  );

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Cache Duration
  static const Duration videoCacheDuration = Duration(hours: 24);
  static const Duration imageCacheDuration = Duration(days: 7);

  // Error Messages
  static const String networkError = 'Please check your internet connection';
  static const String uploadError = 'Failed to upload. Please try again';
  static const String playbackError = 'Error playing video. Please try again';
  static const String authError = 'Authentication failed. Please login again';

  // View Milestones
  static const Map<int, Map<String, dynamic>> viewMilestones = {
    1: {'views': 1000, 'reward': 40},    // 1K views - ₹40
    2: {'views': 5000, 'reward': 200},   // 5K views - ₹200
    3: {'views': 10000, 'reward': 400},  // 10K views - ₹400
    4: {'views': 25000, 'reward': 1000}, // 25K views - ₹1,000
    5: {'views': 50000, 'reward': 2000}, // 50K views - ₹2,000
    6: {'views': 100000, 'reward': 4000},// 100K views - ₹4,000
    7: {'views': 500000, 'reward': 20000},// 500K views - ₹20,000
    8: {'views': 1000000, 'reward': 40000}// 1M views - ₹40,000
  };

  // Button Styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // Layout Constants
  static const double maxContentWidth = 1200.0;
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;

  // Responsive Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // API Timeouts
  static const Duration shortTimeout = Duration(seconds: 10);
  static const Duration mediumTimeout = Duration(seconds: 30);
  static const Duration longTimeout = Duration(minutes: 5);
}