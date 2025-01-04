import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

class VideoProcessor {
  static final VideoProcessor _instance = VideoProcessor._internal();
  factory VideoProcessor() => _instance;
  VideoProcessor._internal();

  static const Map<String, Map<String, dynamic>> qualityPresets = {
    'high': {
      'bitrate': '2500k',
      'resolution': '1920x1080',
      'fps': 30,
      'audioBitrate': '192k',
      'format': 'mp4',
      'codec': 'libx264'
    },
    'medium': {
      'bitrate': '1500k',
      'resolution': '1280x720',
      'fps': 30,
      'audioBitrate': '128k',
      'format': 'mp4',
      'codec': 'libx264'
    },
    'low': {
      'bitrate': '800k',
      'resolution': '854x480',
      'fps': 30,
      'audioBitrate': '96k',
      'format': 'mp4',
      'codec': 'libx264'
    }
  };

  Future<Map<String, dynamic>> processVideoForUpload(
    Uint8List videoBytes,
    String fileName, {
    bool generateHLS = false,
    String quality = 'medium',
    bool generateThumbnail = true,
    Function(double)? onProgress,
    bool checkPermissions = true,
  }) async {
    if (checkPermissions) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final inputPath = '${tempDir.path}/input_$fileName';
      final outputBasePath = '${tempDir.path}/processed';
      
      await Directory(outputBasePath).create(recursive: true);
      
      final inputFile = File(inputPath);
      await inputFile.writeAsBytes(videoBytes);

      onProgress?.call(0.1);

      final mediaInfo = await _extractVideoInfo(inputPath);
      if (mediaInfo == null) throw Exception('Failed to extract video info');

      onProgress?.call(0.2);

      final processedPath = await _processMainVideo(
        inputPath,
        '$outputBasePath/web.mp4',
        quality,
      );

      onProgress?.call(0.5);

      Map<String, Uint8List>? hlsFiles;
      if (generateHLS) {
        hlsFiles = await _generateHLSStream(
          inputPath,
          '$outputBasePath/hls',
          quality,
        );
        onProgress?.call(0.7);
      }

      Uint8List? thumbnail;
      if (generateThumbnail) {
        thumbnail = await _generateThumbnail(inputPath);
        onProgress?.call(0.8);
      }

      final processedVideo = await File(processedPath).readAsBytes();
      
      onProgress?.call(0.9);

      await _cleanup([inputPath, processedPath, outputBasePath]);

      onProgress?.call(1.0);

      return {
        'original': videoBytes,
        'web_optimized': processedVideo,
        'hls': hlsFiles,
        'thumbnail': thumbnail,
        'metadata': {
          'width': mediaInfo.width,
          'height': mediaInfo.height,
          'duration': mediaInfo.duration,
          'filesize': mediaInfo.filesize,
          'format': mediaInfo.title,
          'orientation': mediaInfo.orientation,
          'quality': quality,
          'hasHLS': hlsFiles != null,
        }
      };
    } catch (e) {
      print('Video processing error: $e');
      throw Exception('Failed to process video: $e');
    } finally {
      await VideoCompress.deleteAllCache();
    }
  }

  Future<MediaInfo?> _extractVideoInfo(String videoPath) async {
    try {
      return await VideoCompress.getMediaInfo(videoPath);
    } catch (e) {
      print('Info extraction error: $e');
      return null;
    }
  }

  Future<String> _processMainVideo(
    String inputPath,
    String outputPath,
    String quality,
  ) async {
    final preset = qualityPresets[quality] ?? qualityPresets['medium']!;
    
    final command = '''
      -i $inputPath 
      -c:v ${preset['codec']}
      -b:v ${preset['bitrate']}
      -vf scale=${preset['resolution']}
      -r ${preset['fps']}
      -c:a aac
      -b:a ${preset['audioBitrate']}
      -movflags +faststart
      $outputPath
    ''';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    } else {
      final logs = await session.getOutput();
      print('FFmpeg logs: $logs');
      throw Exception('Failed to process video');
    }
  }

  Future<Map<String, Uint8List>> _generateHLSStream(
    String inputPath,
    String outputDir,
    String quality,
  ) async {
    try {
      final preset = qualityPresets[quality] ?? qualityPresets['medium']!;
      await Directory(outputDir).create(recursive: true);

      final command = '''
        -i $inputPath
        -c:v ${preset['codec']}
        -c:a aac
        -b:a ${preset['audioBitrate']}
        -f hls
        -hls_time 6
        -hls_playlist_type vod
        -hls_segment_filename "$outputDir/segment_%03d.ts"
        -hls_flags independent_segments
        -hls_segment_type mpegts
        -hls_list_size 0
        $outputDir/playlist.m3u8
      ''';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getOutput();
        print('FFmpeg logs: $logs');
        throw Exception('HLS conversion failed');
      }

      final dir = Directory(outputDir);
      final Map<String, Uint8List> files = {};

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          files[name] = await entity.readAsBytes();
        }
      }

      return files;
    } catch (e) {
      print('HLS generation error: $e');
      throw Exception('Failed to generate HLS stream: $e');
    }
  }

  Future<Uint8List> _generateThumbnail(String videoPath) async {
    try {
      final thumbnail = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 50,
        position: -1,
      );

      if (thumbnail == null) {
        throw Exception('Failed to generate thumbnail');
      }

      return thumbnail;
    } catch (e) {
      print('Thumbnail generation error: $e');
      throw Exception('Failed to generate thumbnail: $e');
    }
  }

  Future<void> _cleanup(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete(recursive: true);
        }
      } catch (e) {
        print('Cleanup error for $path: $e');
      }
    }
    await VideoCompress.deleteAllCache();
  }

  List<String> getSupportedFormats() {
    return ['mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm'];
  }

  bool needsOptimization(MediaInfo info) {
    if (info.filesize == null || info.width == null || info.duration == null) {
      return true;
    }

    final maxBitrateStr = qualityPresets['high']!['bitrate']
        .toString()
        .replaceAll('k', '000');
    final maxBitrate = int.parse(maxBitrateStr);
    
    return info.filesize! > 10 * 1024 * 1024 || // Larger than 10MB
           info.width! > 1920 || // Wider than 1080p
           info.duration! > 600; // Longer than 10 minutes
  }

  Future<void> cleanup() async {
    await VideoCompress.deleteAllCache();
    final tempDir = await getTemporaryDirectory();
    final tempFiles = tempDir.listSync();
    
    for (var file in tempFiles) {
      if (file is File && 
          (file.path.endsWith('.mp4') || 
           file.path.endsWith('.m3u8') || 
           file.path.endsWith('.ts'))) {
        await file.delete();
      }
    }
  }
}