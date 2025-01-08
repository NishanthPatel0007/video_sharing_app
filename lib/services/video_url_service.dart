// video_url_service.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoUrlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _allowedChars = 
    'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 6;
  static const String baseUrl = 'for10cloud.com/';
  
  String _generateCode() {
    final random = Random.secure();
    return List.generate(_codeLength, (index) {
      return _allowedChars[random.nextInt(_allowedChars.length)];
    }).join();
  }

  Future<String?> getShareUrl(String videoId) async {
    try {
      final code = await getOrCreateShareCode(videoId);
      return '$baseUrl$code';
    } catch (e) {
      print('Error generating share URL: $e');
      return null;
    }
  }

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

      // Generate new code
      final code = _generateCode();
      
      // Save new code
      await _firestore.collection('video_urls').doc(code).set({
        'videoId': videoId,
        'shortCode': code,
        'createdAt': FieldValue.serverTimestamp(),
        'visits': 0,
        'lastAccessed': FieldValue.serverTimestamp()
      });
      
      return code;
    } catch (e) {
      // If Firestore fails, generate a temporary local code
      final tempCode = _generateCode();
      debugPrint('Using temporary code due to error: $e');
      return tempCode;
    }
  }

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

  Future<void> copyToClipboard(String videoId, BuildContext context) async {
    try {
      final shareUrl = await getShareUrl(videoId);
      if (shareUrl == null) throw Exception('Failed to generate URL');
      
      await Clipboard.setData(ClipboardData(text: shareUrl));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('URL copied to clipboard!'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying to clipboard: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Utility method to delete old/unused URLs
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