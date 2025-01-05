import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoUrlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Removed potentially confusing characters: 0,O,1,I,l
  static const String _allowedChars = 
    'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 6;
  static const String baseUrl = 'for10cloud.com/';  // Removed /v/ prefix

  // Reserved codes that shouldn't be used
  static final Set<String> _reservedCodes = {
    'admin', 'login', 'help', 'about', 'terms', 'video',
    'share', 'test', 'demo', 'support', 'contact', 'dashboard',
    'register', 'password', 'upload', 'profile', 'settings'
  };
  
  String _generateCode() {
    final random = Random.secure();
    String code;
    do {
      code = List.generate(_codeLength, (index) {
        return _allowedChars[random.nextInt(_allowedChars.length)];
      }).join();
    } while (_isReservedCode(code));
    
    return code;
  }

  bool _isReservedCode(String code) {
    return _reservedCodes.contains(code.toLowerCase());
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

      // Generate new code with collision handling
      int attempts = 0;
      const maxAttempts = 5;

      while (attempts < maxAttempts) {
        final code = _generateCode();
        
        // Use transaction to prevent race conditions
        bool success = await _firestore.runTransaction<bool>((transaction) async {
          final docRef = _firestore.collection('video_urls').doc(code);
          final doc = await transaction.get(docRef);

          if (doc.exists) return false;

          transaction.set(docRef, {
            'videoId': videoId,
            'shortCode': code,
            'createdAt': FieldValue.serverTimestamp(),
            'visits': 0,
            'lastAccessed': FieldValue.serverTimestamp(),
            'isActive': true
          });

          return true;
        });

        if (success) return code;
        attempts++;
      }

      throw Exception('Failed to generate unique code after $maxAttempts attempts');
    } catch (e) {
      print('Error generating share code: $e');
      throw Exception('Failed to generate share code: $e');
    }
  }

  Future<String?> getVideoId(String code) async {
    if (code.length != _codeLength || _isReservedCode(code)) return null;
    
    try {
      final doc = await _firestore
          .collection('video_urls')
          .doc(code)
          .get();

      if (doc.exists && doc.data()?['isActive'] == true) {
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
      final code = await getOrCreateShareCode(videoId);
      final shareUrl = '$baseUrl$code';
      
      try {
        await Clipboard.setData(ClipboardData(text: shareUrl));
      } catch (clipboardError) {
        print('Primary clipboard method failed: $clipboardError');
        rethrow;
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('URL copied to clipboard!'),
                      Text(
                        shareUrl,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Copy Again',
              textColor: Colors.white,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: shareUrl));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Failed to copy URL: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> deactivateUrl(String code) async {
    try {
      await _firestore
          .collection('video_urls')
          .doc(code)
          .update({'isActive': false});
    } catch (e) {
      print('Error deactivating URL: $e');
    }
  }

  Future<void> cleanupOldUrls({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final oldUrls = await _firestore
          .collection('video_urls')
          .where('lastAccessed', isLessThan: cutoffDate)
          .where('visits', isLessThan: 10)  // Only delete rarely accessed URLs
          .get();

      for (var doc in oldUrls.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error cleaning up old URLs: $e');
    }
  }

  bool isValidVideoCode(String code) {
    return code.length == _codeLength && 
           !_isReservedCode(code) &&
           code.split('').every((char) => _allowedChars.contains(char));
  }
}