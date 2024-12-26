import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoUrlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Constants for URL generation
  static const String _allowedChars = 
    'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 5;
  static const String _baseUrl = 'https://for10cloud.com/v/';

  // Generate a random code for video URLs
  String _generateCode() {
    final random = Random.secure();
    return List.generate(_codeLength, (index) {
      return _allowedChars[random.nextInt(_allowedChars.length)];
    }).join();
  }

  // Get the full share URL for a video
  Future<String?> getShareUrl(String videoId) async {
    try {
      final code = await getOrCreateShareCode(videoId);
      return '$_baseUrl$code';
    } catch (e) {
      print('Error generating share URL: $e');
      return null;
    }
  }

  // Get or create a share code for a video
  Future<String> getOrCreateShareCode(String videoId) async {
    try {
      // First check if video already has a code
      final existing = await _firestore
          .collection('video_urls')
          .where('videoId', isEqualTo: videoId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.data()['shortCode'];
      }

      // Generate new unique code
      while (true) {
        final code = _generateCode();
        
        // Check if code exists
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
            'lastAccessed': FieldValue.serverTimestamp(),
            'status': 'active'  // Added status field
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
      // Clean the code (remove any path or domain parts)
      final cleanCode = code.split('/').last.split('?').first;
      
      final doc = await _firestore
          .collection('video_urls')
          .doc(cleanCode)
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

  // Copy share URL to clipboard
  Future<void> copyToClipboard(String videoId, BuildContext context) async {
    try {
      final code = await getOrCreateShareCode(videoId);
      final shareUrl = '$_baseUrl$code';
      
      await Clipboard.setData(ClipboardData(text: shareUrl));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL copied to clipboard!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate URL: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Get video visits/analytics
  Future<Map<String, dynamic>> getVideoAnalytics(String videoId) async {
    try {
      final urlDoc = await _firestore
          .collection('video_urls')
          .where('videoId', isEqualTo: videoId)
          .limit(1)
          .get();

      if (urlDoc.docs.isNotEmpty) {
        final data = urlDoc.docs.first.data();
        return {
          'visits': data['visits'] ?? 0,
          'lastAccessed': data['lastAccessed'],
          'shortCode': data['shortCode'],
          'status': data['status'] ?? 'active'
        };
      }
      return {'visits': 0, 'status': 'no_url'};
    } catch (e) {
      print('Error getting video analytics: $e');
      return {'error': e.toString()};
    }
  }

  // Deactivate a share URL
  Future<void> deactivateUrl(String code) async {
    try {
      await _firestore
          .collection('video_urls')
          .doc(code)
          .update({'status': 'inactive'});
    } catch (e) {
      print('Error deactivating URL: $e');
      throw Exception('Failed to deactivate URL');
    }
  }

  // Reactivate a share URL
  Future<void> reactivateUrl(String code) async {
    try {
      await _firestore
          .collection('video_urls')
          .doc(code)
          .update({'status': 'active'});
    } catch (e) {
      print('Error reactivating URL: $e');
      throw Exception('Failed to reactivate URL');
    }
  }

  // Delete old or unused URLs
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

  // Validate a video code
  bool isValidVideoCode(String code) {
    if (code.length != _codeLength) return false;
    return code.split('').every((char) => _allowedChars.contains(char));
  }

  // Parse video code from any URL format
  String? parseVideoCode(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Handle /v/CODE format
      if (uri.path.startsWith('/v/')) {
        return uri.path.substring(3);
      }
      
      // Handle ?video=CODE format
      if (uri.queryParameters.containsKey('video')) {
        return uri.queryParameters['video'];
      }
      
      // Handle direct code
      if (isValidVideoCode(url)) {
        return url;
      }
      
      return null;
    } catch (e) {
      print('Error parsing video code: $e');
      return null;
    }
  }
}