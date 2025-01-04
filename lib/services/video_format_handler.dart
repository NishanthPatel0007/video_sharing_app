import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class VideoFormatHandler {
  // Supported formats with MIME types
  static const Map<String, String> formats = {
    'mp4': 'video/mp4',
    'hls': 'application/x-mpegURL',
    'm3u8': 'application/x-mpegURL',
    'mov': 'video/quicktime',
    'avi': 'video/x-msvideo',
    'mkv': 'video/x-matroska',
    'webm': 'video/webm'
  };

  // Codec configurations for different devices
  static const Map<String, Map<String, dynamic>> codecConfigs = {
    'h264': {
      'profile': 'main',
      'level': '4.0',
      'maxBitrate': 2000000,
      'supportedBy': ['web', 'ios', 'android']
    },
    'hevc': {
      'profile': 'main',
      'level': '4.1',
      'maxBitrate': 2500000,
      'supportedBy': ['ios', 'android']
    },
    'vp9': {
      'profile': '0',
      'level': '4.1',
      'maxBitrate': 2000000,
      'supportedBy': ['web', 'android']
    }
  };

  // Storage endpoints and settings
  static const String r2BaseUrl = 'https://r2.for10cloud.com';
  static const Map<String, int> sizeLimits = {
    'video': 800 * 1024 * 1024, // 800MB
    'thumbnail': 5 * 1024 * 1024 // 5MB
  };

  static bool needsHLSStreaming() {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  static String getAppropriateVideoUrl({
    required String defaultUrl,
    String? hlsUrl,
    bool checkPermissions = true,
  }) {
    if (checkPermissions) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return defaultUrl;
    }

    if (needsHLSStreaming() && hlsUrl != null) {
      return hlsUrl;
    }
    return defaultUrl;
  }

  static Future<VideoPlayerController> getVideoController({
    required String videoUrl,
    String? hlsUrl,
    Map<String, String>? headers,
    bool allowBackgroundPlayback = false,
  }) async {
    final url = getAppropriateVideoUrl(
      defaultUrl: videoUrl,
      hlsUrl: hlsUrl,
    );

    final defaultHeaders = {
      'Accept-Ranges': 'bytes',
      'Access-Control-Allow-Origin': '*',
      'X-Platform-Info': kIsWeb ? 'web' : Platform.operatingSystem,
      'X-HLS-Support': needsHLSStreaming().toString(),
    };

    final mergedHeaders = {
      ...defaultHeaders,
      ...?headers,
    };

    final controller = VideoPlayerController.network(
      url,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: allowBackgroundPlayback,
      ),
      httpHeaders: mergedHeaders,
    );

    try {
      await controller.initialize();
      return controller;
    } catch (e) {
      controller.dispose();
      throw FormatException('Failed to initialize video player: $e');
    }
  }

  static bool isValidFormat(String contentType, {bool checkPermissions = true}) {
    if (checkPermissions) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
    }
    return formats.values.contains(contentType.toLowerCase());
  }

  static Map<String, dynamic> getUploadFormat({
    required String fileName,
    required int fileSize,
    bool generateHLS = false,
  }) {
    final extension = fileName.split('.').last.toLowerCase();
    final isIOS = !kIsWeb && Platform.isIOS;
    final needsTranscoding = !formats.containsKey(extension) || isIOS || generateHLS;

    return {
      'contentType': formats[extension] ?? formats['mp4']!,
      'needsConversion': needsTranscoding,
      'targetFormat': isIOS || generateHLS ? 'hls' : 'mp4',
      'codecConfig': isIOS ? codecConfigs['hevc'] : codecConfigs['h264'],
      'originalFormat': extension,
      'requiresPermissions': true,
      'generateHLS': generateHLS || isIOS
    };
  }

  static Map<String, dynamic> getPlaybackConfig({
    required bool isIOS,
    required bool isWeb,
    required int fileSize,
  }) {
    return {
      'autoplay': !isIOS,
      'preload': isWeb ? 'auto' : 'metadata',
      'bufferSize': _calculateBufferSize(fileSize, isWeb),
      'maxBitrate': isIOS ? codecConfigs['hevc']!['maxBitrate'] 
                        : codecConfigs['h264']!['maxBitrate'],
      'preferredCodec': isIOS ? 'hevc' : 'h264',
      'requiresPermissions': false
    };
  }

  static int _calculateBufferSize(int fileSize, bool isWeb) {
    if (isWeb) return 2 * 1024 * 1024; // 2MB web
    final sizeMB = fileSize ~/ (1024 * 1024);
    if (sizeMB < 100) return 1 * 1024 * 1024; // 1MB small
    if (sizeMB < 500) return 2 * 1024 * 1024; // 2MB medium
    return 4 * 1024 * 1024; // 4MB large
  }

  static String getFormatErrorMessage(String format, {String? details}) {
    switch (format.toLowerCase()) {
      case 'mp4': return details ?? 'MP4 format is supported on all platforms';
      case 'hls': return details ?? 'HLS format is required for iOS devices';
      case 'm3u8': return details ?? 'M3U8 format is compatible with HLS streaming';
      default: return 'Unsupported video format: $format';
    }
  }

  static bool isFormatCompatible(String format, {
    bool checkPermissions = true,
    bool requireHLS = false,
  }) {
    if (checkPermissions) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
    }

    final supportedFormats = getSupportedFormats();
    final isSupported = supportedFormats.contains(format.toLowerCase());
    
    if (!isSupported) return false;
    if (!requireHLS) return true;
    
    return format.toLowerCase() == 'hls' || 
           format.toLowerCase() == 'm3u8' ||
           !needsHLSStreaming();
  }

  static List<String> getSupportedFormats() {
    if (kIsWeb) return ['mp4', 'webm'];
    if (Platform.isIOS) return ['mp4', 'mov', 'm3u8', 'hls'];
    return ['mp4', 'mkv', 'avi', 'webm'];
  }

  static Future<bool> testVideoUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Map<String, dynamic> getStreamingSettings({
    required bool isIOS,
    required bool isWeb,
    required int fileSize,
    bool allowBackgroundPlayback = false,
  }) {
    return {
      'bufferSize': _calculateBufferSize(fileSize, isWeb),
      'maxBitrate': isIOS ? 2500000 : 2000000,
      'segmentDuration': isIOS ? 6 : 4,
      'playlistSize': isIOS ? 3 : 4,
      'retryAttempts': 3,
      'timeout': const Duration(seconds: 10),
      'allowBackground': allowBackgroundPlayback,
      'requiresPermissions': true
    };
  }
}