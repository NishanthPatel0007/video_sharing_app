import 'dart:async';
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
  static const int _maxRetries = 3;
  
  // Cache for generated URLs to prevent unnecessary database calls
  final Map<String, String> _urlCache = {};

  // Get the share URL for a video with retries and caching
  Future<String?> getShareUrl(String videoId) async {
    // Check cache first
    if (_urlCache.containsKey(videoId)) {
      return _urlCache[videoId];
    }

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final code = await getOrCreateShareCode(videoId);
        final url = '$_baseUrl$code';
        
        // Cache the successful result
        _urlCache[videoId] = url;
        return url;
      } catch (e) {
        debugPrint('Error generating share URL (attempt ${attempt + 1}): $e');
        if (attempt == _maxRetries - 1) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return null;
  }

  // Copy URL to clipboard with platform-specific handling
  Future<void> copyToClipboard(String videoId, BuildContext context) async {
    String? shareUrl;
    try {
      // Generate or get URL first
      shareUrl = await getShareUrl(videoId);
      if (shareUrl == null) throw Exception('Failed to generate share URL');

      // Try different clipboard methods based on platform
      bool success = false;
      
      // Method 1: Standard Flutter clipboard
      try {
        await Clipboard.setData(ClipboardData(text: shareUrl));
        success = true;
      } catch (e) {
        debugPrint('Standard clipboard failed: $e');
      }

      // Method 2: Web Clipboard API
      if (!success && kIsWeb) {
        try {
          success = await _webCopyToClipboard(shareUrl);
        } catch (e) {
          debugPrint('Web clipboard API failed: $e');
        }
      }

      // Method 3: Legacy execCommand
      if (!success && kIsWeb) {
        success = await _legacyCopyToClipboard(shareUrl);
      }

      // Show appropriate feedback
      if (context.mounted) {
        if (success) {
          _showSuccessSnackbar(context);
        } else {
          _showManualCopyDialog(context, shareUrl);
        }
      }
    } catch (e) {
      debugPrint('Copy to clipboard error: $e');
      if (context.mounted) {
        _showErrorSnackbar(context, shareUrl);
      }
    }
  }

  // Web Clipboard API implementation
  Future<bool> _webCopyToClipboard(String text) async {
    try {
      await html.window.navigator.clipboard?.writeText(text);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Legacy clipboard implementation for older browsers
  Future<bool> _legacyCopyToClipboard(String text) async {
    final textarea = html.TextAreaElement()
      ..value = text
      ..style.position = 'fixed'
      ..style.left = '-9999px'
      ..style.opacity = '0';
    html.document.body?.append(textarea);

    try {
      textarea.select();
      final success = html.document.execCommand('copy');
      textarea.remove();
      return success;
    } catch (e) {
      textarea.remove();
      return false;
    }
  }

  // Get video ID from share code with improved error handling
  Future<String?> getVideoId(String code) async {
    try {
      // Clean and validate the code
      final cleanCode = _cleanVideoCode(code);
      if (cleanCode == null) return null;

      final doc = await _firestore
          .collection('video_urls')
          .doc(cleanCode)
          .get();

      if (!doc.exists) return null;

      // Update analytics in the background
      _updateAnalytics(doc.reference).catchError((e) {
        debugPrint('Analytics update error: $e');
      });

      return doc.data()?['videoId'];
    } catch (e) {
      debugPrint('Error getting video ID: $e');
      return null;
    }
  }

  // Create or get existing share code with improved error handling
  Future<String> getOrCreateShareCode(String videoId) async {
    try {
      // Check existing code first
      final existing = await _firestore
          .collection('video_urls')
          .where('videoId', isEqualTo: videoId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.data()['shortCode'];
      }

      // Generate new code with retries
      String? code;
      int attempts = 0;
      while (attempts < _maxRetries) {
        code = _generateCode();
        final doc = await _firestore
            .collection('video_urls')
            .doc(code)
            .get();

        if (!doc.exists) {
          // Save new code with platform info
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
              'isWebApp': kIsWeb,
            }
          });
          return code;
        }
        attempts++;
      }
      throw Exception('Failed to generate unique code after $_maxRetries attempts');
    } catch (e) {
      debugPrint('Error generating share code: $e');
      throw Exception('Failed to generate share code: $e');
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

  // Update analytics in the background
  Future<void> _updateAnalytics(DocumentReference docRef) async {
    try {
      await docRef.update({
        'visits': FieldValue.increment(1),
        'lastAccessed': FieldValue.serverTimestamp(),
        'accessInfo': {
          'userAgent': html.window.navigator.userAgent,
          'platform': html.window.navigator.platform,
          'timestamp': FieldValue.serverTimestamp(),
          'isWebApp': kIsWeb,
        }
      });
    } catch (e) {
      debugPrint('Analytics update failed: $e');
    }
  }

  // UI Feedback Methods
  void _showSuccessSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String? url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Failed to copy URL'),
        backgroundColor: Colors.red,
        action: url != null ? SnackBarAction(
          label: 'Show URL',
          textColor: Colors.white,
          onPressed: () => _showManualCopyDialog(context, url),
        ) : null,
      ),
    );
  }

  void _showManualCopyDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please copy this URL manually:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            SelectableText(
              url,
              style: const TextStyle(fontFamily: 'monospace'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}