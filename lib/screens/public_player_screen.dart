// lib/screens/public_player_screen.dart
import 'dart:async';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import '../models/view_level.dart';
import '../services/storage_service.dart';
import '../services/video_url_service.dart';

class PublicVideoPage extends StatefulWidget {
  final String videoCode;
  const PublicVideoPage({Key? key, required this.videoCode}) : super(key: key);

  @override
  State<PublicVideoPage> createState() => _PublicVideoPageState();
}

class _PublicVideoPageState extends State<PublicVideoPage> {
  bool _isLoading = true;
  String? _error;
  Video? _video;
  VideoPlayerController? _controller;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isFullScreen = false;
  bool _viewCounted = false;
  bool _hasError = false;
  final StorageService _storage = StorageService();
  final VideoUrlService _urlService = VideoUrlService();

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final videoId = await _urlService.getVideoId(widget.videoCode);
      if (videoId == null) throw Exception('Video not found');

      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (!videoDoc.exists) throw Exception('Video not found');

      final video = Video.fromFirestore(videoDoc);

      // Initialize video player
      _controller = VideoPlayerController.network(
        video.videoUrl,
        httpHeaders: _getVideoHeaders(),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _controller!.initialize();
      _controller!.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _video = video;
          _isLoading = false;
        });
        _controller!.play();
        _startHideControlsTimer();
      }

    } catch (e) {
      print('Error loading video: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Map<String, String> _getVideoHeaders() {
    final isSafari = html.window.navigator.userAgent.toLowerCase().contains('safari') &&
                     !html.window.navigator.userAgent.toLowerCase().contains('chrome');
    final headers = {
      'Accept-Ranges': 'bytes',
      'Access-Control-Allow-Origin': '*',
    };

    if (isSafari) {
      headers['Range'] = 'bytes=0-';
    }

    return headers;
  }

  void _videoListener() {
    if (_controller?.value.hasError ?? false) {
      setState(() {
        _error = 'Video playback error';
        _hasError = true;
      });
    }

    // Count view after 5 seconds of playback
    if (!_viewCounted && 
        (_controller?.value.position.inSeconds ?? 0) >= 5) {
      _countView();
    }
  }

  Future<void> _countView() async {
    if (_viewCounted || _video == null) return;
    _viewCounted = true;

    try {
      await _storage.incrementViews(_video!.id);

      final nextLevel = ViewLevel.getNextLevel(_video!.views + 1);
      if (nextLevel != null && 
          _video!.views < nextLevel.requiredViews && 
          (_video!.views + 1) >= nextLevel.requiredViews) {
        _showMilestoneAchieved(nextLevel);
      }
    } catch (e) {
      print('Failed to count view: $e');
    }
  }

  void _showMilestoneAchieved(ViewLevel level) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1633),
        title: const Text(
          '🎉 New Milestone!',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${level.displayText}\nAchieved',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
        _startHideControlsTimer();
      }
    });
  }

  void _seekRelative(Duration duration) {
    if (_controller == null) return;
    final newPosition = _controller!.value.position + duration;
    _controller!.seekTo(newPosition);
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (_video != null) ...[
                    Expanded(
                      child: Text(
                        _video!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Video Player
            Expanded(
              child: _isLoading ? 
                const Center(child: CircularProgressIndicator()) :
                _error != null ?
                  _buildError() :
                  _buildVideoPlayer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null) return const SizedBox();

    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),

            // Controls Overlay
            if (_showControls)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

            if (_showControls)
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(_controller!.value.position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12
                              ),
                              activeTrackColor: const Color(0xFF8257E5),
                              inactiveTrackColor: Colors.grey[700],
                              thumbColor: const Color(0xFF8257E5),
                            ),
                            child: Slider(
                              value: _controller!.value.position.inMilliseconds
                                  .toDouble(),
                              min: 0,
                              max: _controller!.value.duration.inMilliseconds
                                  .toDouble(),
                              onChanged: (value) {
                                _controller!.seekTo(
                                  Duration(milliseconds: value.toInt())
                                );
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_controller!.value.duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Control Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_5),
                          color: Colors.white,
                          iconSize: 32,
                          onPressed: () => _seekRelative(
                            const Duration(seconds: -5)
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _controller!.value.isPlaying 
                              ? Icons.pause 
                              : Icons.play_arrow
                          ),
                          color: Colors.white,
                          iconSize: 48,
                          onPressed: _togglePlay,
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_5),
                          color: Colors.white,
                          iconSize: 32,
                          onPressed: () => _seekRelative(
                            const Duration(seconds: 5)
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isFullScreen 
                              ? Icons.fullscreen_exit 
                              : Icons.fullscreen
                          ),
                          color: Colors.white,
                          iconSize: 32,
                          onPressed: _toggleFullScreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // Loading Indicator
            if (_controller!.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF8257E5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _error ?? 'Video not found',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8257E5),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}