import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import '../models/view_level.dart';
import '../services/storage_service.dart';
import '../utils/platform_helper.dart';

class PlayerScreen extends StatefulWidget {
  final Video video;
  
  const PlayerScreen({
    Key? key,
    required this.video,
  }) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _isFullScreen = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _viewCounted = false;
  bool _isPlaying = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  final StorageService _storage = StorageService();
  
  // Platform detection
  final bool _isMobile = PlatformHelper.isMobileBrowser;
  final bool _isSafari = PlatformHelper.isSafariBrowser;
  final bool _isIOS = PlatformHelper.isIOSBrowser;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    setState(() => _isBuffering = true);
    
    try {
      // Configure video headers based on platform
      Map<String, String> headers = {
        'Accept-Ranges': 'bytes',
        'Access-Control-Allow-Origin': '*',
      };

      // Add platform-specific headers
      if (_isIOS || _isSafari) {
        headers['Range'] = 'bytes=0-';
      }

      // Initialize controller with platform-specific settings
      _controller = VideoPlayerController.network(
        widget.video.videoUrl,
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _controller.initialize();
      _controller.addListener(_videoListener);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isBuffering = false;
          _hasError = false;
        });
        _controller.play();
        _startHideControlsTimer();
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
          _hasError = true;
          _errorMessage = _getErrorMessage(e.toString());
        });
      }
    }
  }

  String _getErrorMessage(String error) {
    // Handle common error cases
    if (error.contains('MEDIA_ERR_SRC_NOT_SUPPORTED')) {
      return 'This video format is not supported on your device. Please try a different browser or device.';
    } else if (error.contains('MEDIA_ERR_NETWORK')) {
      return 'Network error occurred. Please check your connection and try again.';
    } else if (error.contains('MEDIA_ERR_DECODE')) {
      return 'Unable to decode video. The file might be corrupted.';
    }
    return 'Error loading video: $error';
  }

  void _videoListener() {
    if (!mounted) return;

    // Handle buffering state
    final isBuffering = _controller.value.isBuffering;
    if (_isBuffering != isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }

    // Handle playback state
    if (_isPlaying != _controller.value.isPlaying) {
      setState(() => _isPlaying = _controller.value.isPlaying);
    }

    // Count view after sufficient playback
    if (!_viewCounted && 
        _controller.value.position >= const Duration(seconds: 5)) {
      _countView();
    }

    // Handle errors during playback
    if (_controller.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _getErrorMessage(_controller.value.errorDescription ?? '');
      });
    }
  }

  Future<void> _countView() async {
    if (_viewCounted) return;
    _viewCounted = true;
    
    try {
      await _storage.incrementViews(widget.video.id);
      
      // Check for milestone achievement
      final nextLevel = ViewLevel.getNextLevel(widget.video.views + 1);
      if (nextLevel != null && widget.video.views < nextLevel.requiredViews && 
          (widget.video.views + 1) >= nextLevel.requiredViews) {
        _showMilestoneAchieved(nextLevel);
      }
    } catch (e) {
      print('Failed to increment views: $e');
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
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
      _startHideControlsTimer();
    }
    setState(() {});
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
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _seekTo(Duration position) {
    _controller.seekTo(position);
    _startHideControlsTimer();
  }

  void _seekRelative(Duration duration) {
    final newPosition = _controller.value.position + duration;
    _seekTo(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Player
            Center(
              child: _hasError 
                ? _buildErrorWidget()
                : _buildVideoPlayer(),
            ),

            // Top Bar
            if (!_isFullScreen)
              _buildTopBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const CircularProgressIndicator(
        color: Colors.white,
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            VideoPlayer(_controller),

            // Controls Overlay
            if (_showControls)
              _buildControlsOverlay(),

            // Loading Indicator
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Controls
          _buildTopControls(),

          // Bottom Controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProgressBar(),
              _buildBottomControls(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: _toggleFullScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final duration = _controller.value.duration;
    final position = _controller.value.position;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _formatDuration(position),
            style: const TextStyle(color: Colors.white),
          ),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble(),
                min: 0,
                max: duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  _seekTo(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
          ),
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white),
            onPressed: () => _seekRelative(const Duration(seconds: -10)),
          ),
          IconButton(
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
            onPressed: _togglePlay,
          ),
          IconButton(
            icon: const Icon(Icons.forward_10, color: Colors.white),
            onPressed: () => _seekRelative(const Duration(seconds: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black54,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              widget.video.title,
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline,
          size: 64,
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _initializeVideo,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8257E5),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}