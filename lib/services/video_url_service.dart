import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class VideoUrlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Constants for URL and code generation
  static const String _allowedChars = 
    'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 5;
  static const String baseUrl = 'for10cloud.com/v/';
  
  // Generate a random code for video URLs
  String _generateCode() {
    final random = Random.secure();
    return List.generate(_codeLength, (index) {
      return _allowedChars[random.nextInt(_allowedChars.length)];
    }).join();
  }

  // Get complete share URL for a video
  Future<String?> getShareUrl(String videoId) async {
    try {
      final code = await getOrCreateShareCode(videoId);
      return 'https://$baseUrl$code';
    } catch (e) {
      print('Error generating share URL: $e');
      return null;
    }
  }

  // Get or create a share code for a video
  Future<String> getOrCreateShareCode(String videoId) async {
    try {
      // Check if video already has a code
      final existing = await _firestore
          .collection('video_urls')
          .where('videoId', isEqualTo: videoId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.data()['shortCode'];
      }

      // Generate new code
      while (true) {
        final code = _generateCode();
        
        final doc = await _firestore
            .collection('video_urls')
            .doc(code)
            .get();

        if (!doc.exists) {
          // Save new code
          await _firestore.collection('video_urls').doc(code).set({
            'videoId': videoId,
            'shortCode': code,
            'createdAt': FieldValue.serverTimestamp(),
            'visits': 0,
            'lastAccessed': FieldValue.serverTimestamp()
          });
          
          return code;
        }
      }
    } catch (e) {
      print('Error generating share code: $e');
      throw Exception('Failed to generate share code: $e');
    }
  }

  // Get video ID from share code
  Future<String?> getVideoId(String code) async {
    try {
      final doc = await _firestore
          .collection('video_urls')
          .doc(code)
          .get();

      if (doc.exists) {
        // Update visit count and last accessed time
        await doc.reference.update({
          'visits': FieldValue.increment(1),
          'lastAccessed': FieldValue.serverTimestamp()
        });
        
        return doc.data()?['videoId'];
      }
      return null;
    } catch (e) {
      print('Error getting video ID: $e');
      return null;
    }
  }

  // Share video URL across different platforms
  Future<void> shareVideo(String videoId, BuildContext context) async {
    try {
      final shareUrl = await getShareUrl(videoId);
      if (shareUrl == null) throw Exception('Failed to generate share URL');

      if (kIsWeb) {
        // Web platform sharing
        await _webShare(shareUrl, context);
      } else if (Platform.isIOS || Platform.isAndroid) {
        // Mobile platform sharing
        await Share.share(
          shareUrl,
          subject: 'Check out this video!',
        );
      } else {
        // Desktop platform sharing
        await copyToClipboard(videoId, context);
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to share video: $e');
    }
  }

  // Copy to clipboard with platform-specific implementation
  Future<void> copyToClipboard(String videoId, BuildContext context) async {
    try {
      final shareUrl = await getShareUrl(videoId);
      if (shareUrl == null) throw Exception('Failed to generate share URL');

      if (kIsWeb) {
        // Web clipboard handling
        html.window.navigator.clipboard?.writeText(shareUrl);
      } else {
        // Mobile/Desktop clipboard handling
        await Clipboard.setData(ClipboardData(text: shareUrl));
      }
      
      _showSuccessSnackBar(context, 'URL copied to clipboard!');
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to copy URL: $e');
    }
  }

  // Web-specific sharing implementation
  Future<void> _webShare(String url, BuildContext context) async {
    try {
      if (html.window.navigator.share != null) {
        // Native web share if available
        await html.window.navigator.share({
          'title': 'Share Video',
          'text': 'Check out this video!',
          'url': url,
        });
      } else {
        // Fallback to clipboard
        html.window.navigator.clipboard?.writeText(url);
        _showSuccessSnackBar(context, 'URL copied to clipboard!');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to share: $e');
    }
  }

  // Helper method to show success messages
  void _showSuccessSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Helper method to show error messages
  void _showErrorSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Cleanup method for old URLs
  Future<void> deleteUnusedUrls({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final oldUrls = await _firestore
          .collection('video_urls')
          .where('lastAccessed', isLessThan: cutoffDate)
          .get();

      for (var doc in oldUrls.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning up old URLs: $e');
    }
  }
}