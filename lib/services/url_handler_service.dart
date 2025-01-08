import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/video.dart';
import '../screens/dashboard_screen.dart';
import '../screens/error_screen.dart';
import '../screens/landing_page.dart';
import '../screens/public_video_player.dart';

class UrlHandlerService {
  static const String domain = 'for10cloud.com';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if URL is a video share URL
  bool isVideoShareUrl(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      return uri.host == domain && 
             uri.pathSegments.length == 1 && 
             uri.pathSegments[0].length == 6;
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      return false;
    }
  }

  // Handle URL routing
  Future<Widget> handleUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw UrlHandlingException('Invalid URL format');
      }

      // Landing page
      if (uri.host == domain && uri.pathSegments.isEmpty) {
        return const LandingPage();
      }

      // Video share URL
      if (isVideoShareUrl(url)) {
        final code = uri.pathSegments[0];
        return await _handleVideoCode(code);
      }

      throw UrlHandlingException('Unknown URL pattern');
    } on UrlHandlingException catch (e) {
      debugPrint('URL handling error: $e');
      return ErrorScreen(
        error: e.message,
        onRetry: () => const LandingPage(),
      );
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return ErrorScreen(
        error: 'Failed to process URL',
        onRetry: () => const LandingPage(),
      );
    }
  }

  Future<Widget> _handleVideoCode(String code) async {
    try {
      // Validate code format
      if (!RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(code)) {
        throw VideoCodeException('Invalid video code format');
      }

      // Get video URL mapping
      final videoUrlDoc = await _firestore
          .collection('video_urls')
          .doc(code)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw VideoCodeException('Request timed out'),
          );

      if (!videoUrlDoc.exists) {
        throw VideoCodeException('Video not found');
      }

      final videoId = videoUrlDoc.data()?['videoId'];
      if (videoId == null || videoId is! String) {
        throw VideoCodeException('Invalid video reference');
      }

      // Get video details
      final videoDoc = await _firestore
          .collection('videos')
          .doc(videoId)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw VideoCodeException('Video data fetch timed out'),
          );

      if (!videoDoc.exists) {
        throw VideoCodeException('Video data not found');
      }

      final video = Video.fromFirestore(videoDoc);

      // Update analytics in background
      _updateAnalytics(videoDoc.reference, videoUrlDoc.reference)
          .catchError((e) => debugPrint('Analytics update failed: $e'));

      return _DashboardRedirect(video: video);
    } on VideoCodeException catch (e) {
      return ErrorScreen(
        error: e.message,
        onRetry: () => const LandingPage(),
      );
    } on FirebaseException catch (e) {
      debugPrint('Firebase error: $e');
      return ErrorScreen(
        error: 'Failed to load video data',
        onRetry: () => const LandingPage(),
      );
    } catch (e) {
      debugPrint('Video code handling error: $e');
      return ErrorScreen(
        error: 'Failed to load video',
        onRetry: () => const LandingPage(),
      );
    }
  }

  Future<void> _updateAnalytics(
    DocumentReference videoRef,
    DocumentReference urlRef,
  ) async {
    try {
      final batch = _firestore.batch();
      batch.update(videoRef, {
        'views': FieldValue.increment(1),
        'lastViewed': FieldValue.serverTimestamp(),
      });
      batch.update(urlRef, {
        'visits': FieldValue.increment(1),
        'lastAccessed': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      // Log but don't throw - analytics failures shouldn't break video playback
      debugPrint('Failed to update analytics: $e');
    }
  }
}

// Custom exceptions
class UrlHandlingException implements Exception {
  final String message;
  const UrlHandlingException(this.message);
  @override
  String toString() => 'UrlHandlingException: $message';
}

class VideoCodeException implements Exception {
  final String message;
  const VideoCodeException(this.message);
  @override
  String toString() => 'VideoCodeException: $message';
}

// Temporary dashboard that redirects to video player
class _DashboardRedirect extends StatefulWidget {
  final Video video;
  const _DashboardRedirect({required this.video});

  @override
  State<_DashboardRedirect> createState() => _DashboardRedirectState();
}

class _DashboardRedirectState extends State<_DashboardRedirect> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PublicVideoPlayer(video: widget.video),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const DashboardScreen();
  }
} 