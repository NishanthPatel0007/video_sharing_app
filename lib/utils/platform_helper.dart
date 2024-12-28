// lib/utils/platform_helper.dart
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

class PlatformHelper {
  static bool get isMobileBrowser {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mobile') || 
           userAgent.contains('android') || 
           userAgent.contains('iphone') ||
           userAgent.contains('ipad');
  }

  static bool get isSafariBrowser {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('safari') && !userAgent.contains('chrome');
  }

  static bool get isIOSBrowser {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') || 
           userAgent.contains('ipad') || 
           userAgent.contains('ipod');
  }

  static bool get isChromeBrowser {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('chrome');
  }

  static bool get isFirefoxBrowser {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('firefox');
  }

  static bool get isEdgeBrowser {
    if (!kIsWeb) return false;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('edg');
  }

  static bool get supportsWebM {
    if (!kIsWeb) return false;
    final videoElement = html.VideoElement();
    return videoElement.canPlayType('video/webm') != '';
  }

  static bool get supportsHEVC {
    if (!kIsWeb) return false;
    final videoElement = html.VideoElement();
    return videoElement.canPlayType('video/mp4; codecs="hevc"') != '';
  }

  static Map<String, String> getOptimalVideoFormat() {
    if (isIOSBrowser || isSafariBrowser) {
      return {
        'format': 'mp4',
        'codec': 'h264',
      };
    }
    if (supportsHEVC) {
      return {
        'format': 'mp4',
        'codec': 'hevc',
      };
    }
    if (supportsWebM) {
      return {
        'format': 'webm',
        'codec': 'vp9',
      };
    }
    return {
      'format': 'mp4',
      'codec': 'h264',
    };
  }

  static Map<String, String> getCustomHeaders() {
    Map<String, String> headers = {
      'Accept-Ranges': 'bytes',
      'Access-Control-Allow-Origin': '*',
    };

    if (isIOSBrowser || isSafariBrowser) {
      headers['Range'] = 'bytes=0-';
    }

    return headers;
  }

  static String getBrowserInfo() {
    if (!kIsWeb) return 'Not a web platform';
    
    final userAgent = html.window.navigator.userAgent;
    final platform = html.window.navigator.platform;
    final language = html.window.navigator.language;
    final vendor = html.window.navigator.vendor;

    return {
      'userAgent': userAgent,
      'platform': platform,
      'language': language,
      'vendor': vendor,
      'isMobile': isMobileBrowser,
      'isSafari': isSafariBrowser,
      'isIOS': isIOSBrowser,
      'isChrome': isChromeBrowser,
      'isFirefox': isFirefoxBrowser,
      'isEdge': isEdgeBrowser,
      'supportsWebM': supportsWebM,
      'supportsHEVC': supportsHEVC,
    }.toString();
  }

static Future<bool> get hasClipboardPermission async {
    if (!kIsWeb) return true;
    try {
      final permission = await html.window.navigator
          .permissions?.query({'name': 'clipboard-write'});
      return permission?.state == 'granted';
    } catch (_) {
      return false;
    }
  }
}