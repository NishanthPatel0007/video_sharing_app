// lib/services/video_url_service.dart
import 'dart:html' as html;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoUrlService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _baseUrl = 'https://for10cloud.com/v/';
  static const String _allowedChars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 5;

  // Get the share URL for a video
  Future<String?> getShareUrl(String videoId) async {
    try {
      final code = await getOrCreateShareCode(videoId);
      return '$_baseUrl$code';
    } catch (e) {
      debugPrint('Error generating share URL: $e');
      return null;
    }
  }

  // Copy URL to clipboard with browser compatibility
  Future<void> copyToClipboard(String videoId, BuildContext context) async {
    try {
      final code = await getOrCreateShareCode(videoId);
      final shareUrl = '$_baseUrl$code';
      
      if (kIsWeb) {
        await _webCopyToClipboard(shareUrl);
      } else {
        await Clipboard.setData(ClipboardData(text: shareUrl));
      }
      
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
            content: Text('Failed to copy URL: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Copy to clipboard error: $e');
    }
  }

  // Web-specific clipboard handling
  Future<void> _webCopyToClipboard(String text) async {
    try {
      // Try modern clipboard API first
      if (html.window.navigator.clipboard != null) {
        await html.window.navigator.clipboard?.writeText(text);
        return;
      }
      
      // Fallback for older browsers
      final textarea = html.TextAreaElement()
        ..value = text
        ..style.position = 'fixed'
        ..style.left = '-9999px'
        ..style.opacity = '0';
      html.document.body?.append(textarea);
      
      // Select and copy
      textarea.select();
      final successful = html.document.execCommand('copy');
      textarea.remove();

      if (!successful) throw Exception('Copy command failed');
    } catch (e) {
      debugPrint('Web clipboard error: $e');
      throw Exception('Failed to copy text');
    }
  }

  // Get video ID from share code
  Future<String?> getVideoId(String code) async {
    try {
      // Clean the code from URL
      final cleanCode = _cleanVideoCode(code);
      if (cleanCode == null) return null;
      
      final doc = await _firestore
          .collection('video_urls')
          .doc(cleanCode)
          .get();

      if (doc.exists) {
        // Update analytics
        await doc.reference.update({
          'visits': FieldValue.increment(1),
          'lastAccessed': FieldValue.serverTimestamp(),
          'browserInfo': {
            'userAgent': html.window.navigator.userAgent,
            'platform': html.window.navigator.platform,
            'timestamp': FieldValue.serverTimestamp(),
          }
        });
        
        return doc.data()?['videoId'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting video ID: $e');
      return null;
    }
  }

  // Create or get existing share code
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

      // Generate new code
      String? code;
      int attempts = 0;
      const maxAttempts = 5;

      while (attempts < maxAttempts) {
        code = _generateCode();
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
            'status': 'active',
            'creationInfo': {
              'userAgent': html.window.navigator.userAgent,
              'platform': html.window.navigator.platform,
              'timestamp': FieldValue.serverTimestamp(),
            }
          });
          
          return code;
        }
        attempts++;
      }
      
      throw Exception('Failed to generate unique code after $maxAttempts attempts');
    } catch (e) {
      debugPrint('Error generating share code: $e');
      throw Exception('Failed to generate share code');
    }
  }

  // Generate random code
  String _generateCode() {
    final random = Random.secure();
    return List.generate(_codeLength, (index) {
      return _allowedChars[random.nextInt(_allowedChars.length)];
    }).join();
  }

  // Clean video code from URL
  String? _cleanVideoCode(String code) {
    try {
      // Handle full URLs
      if (code.contains('/')) {
        final uri = Uri.parse(code);
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'v') {
          code = uri.pathSegments[1];
        } else {
          code = uri.pathSegments.last;
        }
      }
      
      // Clean query parameters
      code = code.split('?').first;
      
      // Validate code format
      if (code.length == _codeLength && 
          code.split('').every((char) => _allowedChars.contains(char))) {
        return code;
      }
      return null;
    } catch (e) {
      debugPrint('Error cleaning video code: $e');
      return null;
    }
  }

  // Get video analytics
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
      debugPrint('Error getting video analytics: $e');
      return {'error': e.toString()};
    }
  }

  // Validate video code format
  bool isValidVideoCode(String code) {
    return _cleanVideoCode(code) != null;
  }

  // Parse video code from any URL format
  String? parseVideoCode(String url) {
    return _cleanVideoCode(url);
  }
}