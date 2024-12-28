import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import '../models/view_level.dart';
import '../services/storage_service.dart';
import '../services/video_url_service.dart';
import '../utils/platform_helper.dart';

class PublicVideoPage extends StatefulWidget {
  final String videoCode;
  
  const PublicVideoPage({
    Key? key, 
    required this.videoCode
  }) : super(key: key);

  @override
  State<PublicVideoPage> createState() => _PublicVideoPageState();
}

class _PublicVideoPageState extends State<PublicVideoPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _error;
  Video? _video;
  VideoPlayerController? _controller;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _progressTimer;
  bool _isFullScreen = false;
  bool _viewCounted = false;
  bool _isBuffering = false;
  double _currentVideoPosition = 0.0;
  
  final StorageService _storage = StorageService();
  final VideoUrlService _urlService = VideoUrlService();

  // Platform detection
  final bool _isMobile = PlatformHelper.isMobileBrowser;
  final bool _isSafari = PlatformHelper.isSafariBrowser;
  final bool _isIOS = PlatformHelper.isIOSBrowser;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasError = false;
    });

    try {
      final videoId = await _urlService.getVideoId(widget.videoCode);
      if (videoId == null) throw Exception('Video not found');

      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (!videoDoc.exists) throw Exception('Video not found');

      final video = Video.fromFirestore(videoDoc);

      // Initialize video player with platform-specific settings
      await _initializeVideoPlayer(video);

      if (mounted) {
        setState(() {
          _video = video;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error loading video: $e');
      if (mounted) {
        setState(() {
          _error = _getErrorMessage(e);
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _initializeVideoPlayer(Video video) async {
    try {
      // Configure platform-specific headers
      Map<String, String> headers = {
        'Accept-Ranges': 'bytes',
        'Access-Control-Allow-Origin': '*',
      };

      if (_isIOS || _isSafari) {
        headers['Range'] = 'bytes=0-';
      }

      _controller = VideoPlayerController.network(
        video.videoUrl,
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _controller!.initialize();
      _controller!.addListener(_videoListener);

      // Auto-play with sound off initially
      _controller!.setVolume(0.0);
      _controller!.play();
      _startHideControlsTimer();

      // Start progress tracking
      _startProgressTracking();

    } catch (e) {
      throw Exception('Failed to initialize video player: $e');
    }
  }

  String _getErrorMessage(dynamic error) {
    String message = error.toString();
    
    // Handle common error cases
    if (message.contains('MEDIA_ERR_SRC_NOT_SUPPORTED')) {
      return 'This video format is not supported on your device. Please try a different browser or device.';
    } else if (message.contains('permission-denied')) {
      return 'Unable to access video. Please check your connection and try again.';
    } else if (message.contains('not-found')) {
      return 'Video not found or has been removed.';
    } else if (message.contains('MEDIA_ERR_NETWORK')) {
      return 'Network error occurred. Please check your connection and try again.';
    }

    return 'Error loading video: $message';
  }

  void _videoListener() {
    if (!mounted) return;

    // Handle buffering state
    final isBuffering = _controller?.value.isBuffering ?? false;
    if (_isBuffering != isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }

    // Update video position
    if (_controller?.value.isPlaying ?? false) {
      setState(() {
        _currentVideoPosition = _controller!.value.position.inMilliseconds /
            _controller!.value.duration.inMilliseconds;
      });
    }

    // Handle errors
    if (_controller?.value.hasError ?? false) {
      setState(() {
        _hasError = true;
        _error = _getErrorMessage(_controller!.value.errorDescription);
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
      debugPrint('Failed to count view: $e');
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

  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_controller?.value.isPlaying ?? false) {
        setState(() {});
      }
    });
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

  void _seekRelative(Duration duration) {
    if (_controller == null) return;
    final newPosition = _controller!.value.position + duration;
    _controller!.seekTo(newPosition);
    _startHideControlsTimer();
  }

  Future<void> _retry() async {
    _controller?.dispose();
    _controller = null;
    await _loadVideo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    return Column(
      children: [
        // Video Player
        Expanded(
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video
                AspectRatio(
                  aspectRatio: _controller?.value.aspectRatio ?? 16 / 9,
                  child: VideoPlayer(_controller!),
                ),

                // Loading Indicator
                if (_isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),

                // Controls Overlay
                if (_showControls)
                  _buildControls(),
              ],
            ),
          ),
        ),

        // Video Info
        if (_video != null && !_isFullScreen)
          _buildVideoInfo(),
      ],
    );
  }

  Widget _buildControls() {
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
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Bar
          _buildTopBar(),

          // Bottom Controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress Bar
              _buildProgressBar(),

              // Control Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10),
                      color: Colors.white,
                      onPressed: () => _seekRelative(
                        const Duration(seconds: -10)
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _controller?.value.isPlaying ?? false
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      color: Colors.white,
                      iconSize: 48,
                      onPressed: _togglePlay,
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10),
                      color: Colors.white,
                      onPressed: () => _seekRelative(
                        const Duration(seconds: 10)
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                      ),
                      color: Colors.white,
                      onPressed: _toggleFullScreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_controller == null) return const SizedBox();

    return ValueListenableBuilder(
      valueListenable: _controller!,
      builder: (context, VideoPlayerValue value, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                _formatDuration(value.position),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF8257E5),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: const Color(0xFF8257E5),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: value.position.inMilliseconds.toDouble(),
                    min: 0,
                    max: value.duration.inMilliseconds.toDouble(),
                    onChanged: (position) {
                      _controller!.seekTo(Duration(
                        milliseconds: position.toInt()
                      ));
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(value.duration),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(8),
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
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E1B2C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _video!.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _video!.getFormattedViews(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const Text(
                ' • ',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                _video!.getTimeAgo(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple,
                child: Text(
                  (_video!.userEmail ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _video!.userEmail ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'Uploader',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _retry,
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
      ),
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
    _progressTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}