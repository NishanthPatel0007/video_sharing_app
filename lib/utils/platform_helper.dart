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
}