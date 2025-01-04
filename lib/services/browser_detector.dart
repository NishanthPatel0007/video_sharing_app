import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class BrowserDetector {
  // Singleton instance
  static final BrowserDetector _instance = BrowserDetector._internal();
  factory BrowserDetector() => _instance;
  BrowserDetector._internal();

  // Browser types
  static const String SAFARI = 'Safari';
  static const String CHROME = 'Chrome';
  static const String FIREFOX = 'Firefox';
  static const String EDGE = 'Edge';
  static const String OPERA = 'Opera';
  static const String UNKNOWN = 'Unknown';

  // Platform types
  static const String IOS = 'iOS';
  static const String ANDROID = 'Android';
  static const String WEB = 'Web';
  static const String DESKTOP = 'Desktop';

  // Cache detection results
  String? _cachedBrowser;
  String? _cachedPlatform;
  bool? _cachedIsMobile;
  Map<String, dynamic>? _cachedCapabilities;

  // Get current browser
  String getCurrentBrowser() {
    if (_cachedBrowser != null) return _cachedBrowser!;

    if (!kIsWeb) {
      _cachedBrowser = UNKNOWN;
      return UNKNOWN;
    }

    final userAgent = html.window.navigator.userAgent.toLowerCase();

    if (userAgent.contains('safari') && !userAgent.contains('chrome')) {
      _cachedBrowser = SAFARI;
    } else if (userAgent.contains('edge')) {
      _cachedBrowser = EDGE;
    } else if (userAgent.contains('firefox')) {
      _cachedBrowser = FIREFOX;
    } else if (userAgent.contains('chrome')) {
      _cachedBrowser = CHROME;
    } else if (userAgent.contains('opera')) {
      _cachedBrowser = OPERA;
    } else {
      _cachedBrowser = UNKNOWN;
    }

    return _cachedBrowser!;
  }

  // Get current platform
  String getCurrentPlatform() {
    if (_cachedPlatform != null) return _cachedPlatform!;

    if (kIsWeb) {
      _cachedPlatform = WEB;
    } else if (Platform.isIOS) {
      _cachedPlatform = IOS;
    } else if (Platform.isAndroid) {
      _cachedPlatform = ANDROID;
    } else {
      _cachedPlatform = DESKTOP;
    }

    return _cachedPlatform!;
  }

  // Check if device is mobile
  bool isMobileDevice() {
    if (_cachedIsMobile != null) return _cachedIsMobile!;

    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      _cachedIsMobile = userAgent.contains('mobile') ||
                       userAgent.contains('android') ||
                       userAgent.contains('iphone');
    } else {
      _cachedIsMobile = Platform.isIOS || Platform.isAndroid;
    }

    return _cachedIsMobile!;
  }

  // Check if browser is Safari
  bool isSafari() {
    return getCurrentBrowser() == SAFARI;
  }

  // Check if platform is iOS
  bool isIOS() {
    return getCurrentPlatform() == IOS;
  }

  // Check if device needs HLS format
  bool needsHLSFormat() {
    return isIOS() || (kIsWeb && isSafari());
  }

  // Get browser capabilities
  Map<String, dynamic> getBrowserCapabilities() {
    if (_cachedCapabilities != null) return _cachedCapabilities!;

    final browser = getCurrentBrowser();
    final platform = getCurrentPlatform();
    final isMobile = isMobileDevice();

    _cachedCapabilities = {
      'browser': browser,
      'platform': platform,
      'isMobile': isMobile,
      'features': {
        'hlsSupport': _hasHLSSupport(browser, platform),
        'mp4Support': _hasMP4Support(browser),
        'autoplaySupport': _hasAutoplaySupport(browser, platform, isMobile),
        'adaptiveBitrateSupport': _hasAdaptiveBitrateSupport(browser),
      },
      'recommended': {
        'format': _getRecommendedFormat(browser, platform),
        'maxBitrate': _getRecommendedBitrate(isMobile),
        'bufferSize': _getRecommendedBufferSize(isMobile),
      }
    };

    return _cachedCapabilities!;
  }

  // Private helper methods
  bool _hasHLSSupport(String browser, String platform) {
    return platform == IOS || browser == SAFARI;
  }

  bool _hasMP4Support(String browser) {
    return true; // All modern browsers support MP4
  }

  bool _hasAutoplaySupport(String browser, String platform, bool isMobile) {
    if (isMobile) {
      return platform == ANDROID && browser != FIREFOX;
    }
    return true;
  }

  bool _hasAdaptiveBitrateSupport(String browser) {
    return browser == CHROME || browser == SAFARI || browser == EDGE;
  }

  String _getRecommendedFormat(String browser, String platform) {
    if (platform == IOS || browser == SAFARI) {
      return 'hls';
    }
    return 'mp4';
  }

  int _getRecommendedBitrate(bool isMobile) {
    if (isMobile) {
      return 2500000; // 2.5 Mbps for mobile
    }
    return 5000000; // 5 Mbps for desktop
  }

  int _getRecommendedBufferSize(bool isMobile) {
    if (isMobile) {
      return 2 * 1024 * 1024; // 2MB for mobile
    }
    return 4 * 1024 * 1024; // 4MB for desktop
  }

  // Video playback compatibility check
  Map<String, dynamic> checkPlaybackCompatibility(String videoUrl) {
    final capabilities = getBrowserCapabilities();
    final isHLS = videoUrl.contains('.m3u8');
    final needsHLS = needsHLSFormat();

    return {
      'isCompatible': isHLS == needsHLS,
      'needsTranscoding': isHLS != needsHLS,
      'recommendedFormat': capabilities['recommended']['format'],
      'canAutoplay': capabilities['features']['autoplaySupport'],
      'adaptiveBitrate': capabilities['features']['adaptiveBitrateSupport'],
      'maxBitrate': capabilities['recommended']['maxBitrate'],
      'bufferSize': capabilities['recommended']['bufferSize'],
    };
  }

  // Clear cached values (useful for testing)
  void clearCache() {
    _cachedBrowser = null;
    _cachedPlatform = null;
    _cachedIsMobile = null;
    _cachedCapabilities = null;
  }
}