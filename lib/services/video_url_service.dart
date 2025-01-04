import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class VideoUrlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Constants for URL and code generation
  static const String _allowedChars = 
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ23456789';
  static const int _codeLength = 6;
  static const String baseUrl = 'for10cloud.com/';

  // Enhanced URL generation with format support
  String _generateCode() {
    final random = Random.secure();
    final codeBuffer = StringBuffer();
    
    for (var i = 0; i < _codeLength; i++) {
      codeBuffer.write(_allowedChars[random.nextInt(_allowedChars.length)]);
    }
    
    return codeBuffer.toString();
  }

  // Get complete share URL with format support
  Future<String?> getShareUrl(String videoId, {bool includeFormat = false}) async {
    try {
      final code = await getOrCreateShareCode(videoId);
      final baseShareUrl = 'https://$baseUrl$code';

      if (!includeFormat) return baseShareUrl;

      final videoDoc = await _firestore.collection('videos').doc(videoId).get();
      final hasHLS = videoDoc.data()?['hasHLSStream'] ?? false;
      
      if (hasHLS && (!kIsWeb && Platform.isIOS)) {
        return '$baseShareUrl?format=hls';
      }
      
      return baseShareUrl;
    } catch (e) {
      print('Error generating share URL: $e');
      return null;
    }
  }

  // Enhanced code generation with retries and format tracking
  Future<String> getOrCreateShareCode(String videoId) async {
    try {
      // Check existing code
      final existing = await _firestore
          .collection('video_urls')
          .where('videoId', isEqualTo: videoId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.data()['shortCode'];
      }

      // Generate new code with retries
      int attempts = 0;
      const maxAttempts = 5;
      
      while (attempts < maxAttempts) {
        final code = _generateCode();
        
        bool success = await FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
          final docRef = _firestore.collection('video_urls').doc(code);
          final doc = await transaction.get(docRef);
          
          if (!doc.exists) {
            // Get video format info
            final videoDoc = await _firestore.collection('videos').doc(videoId).get();
            final videoData = videoDoc.data();

            transaction.set(docRef, {
              'videoId': videoId,
              'shortCode': code,
              'createdAt': FieldValue.serverTimestamp(),
              'visits': 0,
              'lastAccessed': FieldValue.serverTimestamp(),
              'primaryFormat': videoData?['primaryFormat'] ?? 'mp4',
              'hasHLSStream': videoData?['hasHLSStream'] ?? false,
              'createdBy': _auth.currentUser?.uid,
              'isActive': true,
              'analytics': {
                'platforms': {},
                'browsers': {},
                'countries': {},
              }
            });
            return true;
          }
          return false;
        });

        if (success) {
          return code;
        }
        
        attempts++;
      }
      
      throw Exception('Failed to generate unique code after $maxAttempts attempts');
    } catch (e) {
      print('Error generating share code: $e');
      throw Exception('Failed to generate share code: $e');
    }
  }

  // Enhanced video info retrieval with analytics
  Future<Map<String, dynamic>?> getVideoInfo(String code) async {
    try {
      final doc = await _firestore
          .collection('video_urls')
          .doc(code)
          .get();

      if (!doc.exists) return null;

      // Update analytics in a separate transaction
      _firestore.runTransaction((transaction) async {
        final urlRef = _firestore.collection('video_urls').doc(code);
        
        // Update visit count and last accessed
        transaction.update(urlRef, {
          'visits': FieldValue.increment(1),
          'lastAccessed': FieldValue.serverTimestamp(),
          'analytics.platforms.${kIsWeb ? 'web' : Platform.operatingSystem}': FieldValue.increment(1),
        });

        // Track viewer if logged in
        if (_auth.currentUser != null) {
          final analyticsRef = _firestore
              .collection('video_analytics')
              .doc('${code}_${_auth.currentUser!.uid}');
              
          transaction.set(analyticsRef, {
            'userId': _auth.currentUser!.uid,
            'videoCode': code,
            'lastViewed': FieldValue.serverTimestamp(),
            'viewCount': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      });
      
      return {
        'videoId': doc.data()?['videoId'],
        'format': doc.data()?['primaryFormat'],
        'hasHLSStream': doc.data()?['hasHLSStream'] ?? false,
        'isActive': doc.data()?['isActive'] ?? true,
      };
    } catch (e) {
      print('Error getting video info: $e');
      return null;
    }
  }

  // Enhanced sharing with format support
  Future<void> shareVideo(String videoId, BuildContext context) async {
    try {
      final shareUrl = await getShareUrl(videoId, includeFormat: true);
      if (shareUrl == null) throw Exception('Failed to generate share URL');

      if (kIsWeb) {
        await _webShare(shareUrl, context);
      } else if (Platform.isIOS || Platform.isAndroid) {
        await Share.share(
          shareUrl,
          subject: 'Check out this video!',
        );
      } else {
        await copyToClipboard(videoId, context);
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to share video: $e');
    }
  }

  // Enhanced clipboard handling with format support
  Future<void> copyToClipboard(String videoId, BuildContext context) async {
    try {
      final shareUrl = await getShareUrl(videoId, includeFormat: true);
      if (shareUrl == null) throw Exception('Failed to generate share URL');

      if (kIsWeb) {
        html.window.navigator.clipboard?.writeText(shareUrl);
      } else {
        await Clipboard.setData(ClipboardData(text: shareUrl));
      }
      
      _showSuccessSnackBar(context, 'URL copied to clipboard!');
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to copy URL: $e');
    }
  }

  // Web sharing with format support
  Future<void> _webShare(String url, BuildContext context) async {
    try {
      if (html.window.navigator.share != null) {
        await html.window.navigator.share({
          'title': 'Share Video',
          'text': 'Check out this video!',
          'url': url,
        });
      } else {
        html.window.navigator.clipboard?.writeText(url);
        _showSuccessSnackBar(context, 'URL copied to clipboard!');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to share: $e');
    }
  }

  // Update video format information
  Future<void> updateVideoFormat(String code, {
    required String format,
    required bool hasHLSStream,
  }) async {
    try {
      await _firestore
          .collection('video_urls')
          .doc(code)
          .update({
            'primaryFormat': format,
            'hasHLSStream': hasHLSStream,
            'lastUpdated': FieldValue.serverTimestamp(),
            'updatedBy': _auth.currentUser?.uid,
          });
    } catch (e) {
      print('Error updating video format: $e');
    }
  }

  // Enhanced cleanup with analytics preservation
  Future<void> deactivateUrl(String code) async {
    try {
      await _firestore
          .collection('video_urls')
          .doc(code)
          .update({
            'isActive': false,
            'deactivatedAt': FieldValue.serverTimestamp(),
            'deactivatedBy': _auth.currentUser?.uid,
          });
    } catch (e) {
      print('Error deactivating URL: $e');
    }
  }

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

  // Analytics methods
  Future<Map<String, dynamic>> getUrlAnalytics(String code) async {
    try {
      final doc = await _firestore
          .collection('video_urls')
          .doc(code)
          .get();

      return doc.data()?['analytics'] ?? {};
    } catch (e) {
      print('Error getting analytics: $e');
      return {};
    }
  }
}