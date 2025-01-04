import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import '../services/browser_detector.dart';
import '../services/storage_service.dart';
import '../services/video_format_handler.dart';

class PublicVideoPlayer extends StatefulWidget {
  final Video video;
  final VoidCallback onBack;
  final bool allowFullscreen;
  final bool showControls;
  
  const PublicVideoPlayer({
    Key? key,
    required this.video,
    required this.onBack,
    this.allowFullscreen = true,
    this.showControls = true,
  }) : super(key: key);

  @override
  _PublicVideoPlayerState createState() => _PublicVideoPlayerState();
}

class _PublicVideoPlayerState extends State<PublicVideoPlayer> {
  late VideoPlayerController _controller;
  final StorageService _storage = StorageService();
  final BrowserDetector _browserDetector = BrowserDetector();
  
  Timer? _hideTimer;
  Timer? _positionTimer;
  Timer? _bufferingTimer;
  Duration _watchDuration = Duration.zero;
  
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  String _errorMessage = '';
  bool _reportSubmitted = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _incrementViews();
    _startWatchTracking();
  }

  Future<void> _initializePlayer() async {
    setState(() => _isBuffering = true);

    try {
      final capabilities = _browserDetector.getBrowserCapabilities();
      final playbackConfig = VideoFormatHandler.getPlaybackConfig(
        isIOS: capabilities['platform'] == 'iOS',
        isWeb: capabilities['platform'] == 'Web',
        fileSize: widget.video.metadata?['filesize'] ?? 0,
      );

      final videoUrl = VideoFormatHandler.getAppropriateVideoUrl(
        defaultUrl: widget.video.videoUrl,
        hlsUrl: widget.video.hlsUrl,
      );

      _controller = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
        httpHeaders: {
          'Accept-Ranges': 'bytes',
          'Access-Control-Allow-Origin': '*',
          'X-Platform-Info': capabilities['platform'],
          'X-Video-Format': playbackConfig['preferredCodec'],
        },
      );

      await _controller.initialize();
      _controller.addListener(_videoListener);

      // Start buffering timer
      _bufferingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (_controller.value.isPlaying && !_controller.value.isBuffering) {
          timer.cancel();
          if (mounted) setState(() => _isBuffering = false);
        }
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isBuffering = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video playback error';
      });
    }
    
    final isBuffering = _controller.value.isBuffering;
    if (_isBuffering != isBuffering && mounted) {
      setState(() => _isBuffering = isBuffering);
    }

    if (_hideTimer?.isActive ?? false) _hideTimer!.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _startWatchTracking() {
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller.value.isPlaying) {
        setState(() {
          _watchDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _incrementViews() async {
    try {
      await _storage.incrementViews(widget.video.id);
    } catch (e) {
      print('Failed to increment views: $e');
    }
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  void _toggleFullscreen() async {
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  Future<void> _reportVideo() async {
    if (_reportSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reported this video')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to report videos')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please select a reason for reporting:'),
            const SizedBox(height: 16),
            _buildReportOption('Inappropriate content'),
            _buildReportOption('Copyright violation'),
            _buildReportOption('Violent or abusive'),
            _buildReportOption('Other'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        try {
          // Add report to database
          setState(() => _reportSubmitted = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. Thank you for your feedback.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit report: $e')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(Icons.radio_button_off, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(reason),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _positionTimer?.cancel();
    _bufferingTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isFullscreen
          ? _buildPlayerWidget()
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildPlayerWidget()),
                if (!_isFullscreen) _buildVideoInfo(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
                  onPressed: widget.onBack,
                ),
                const Text(
                  'Back',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                Icons.flag,
                color: _reportSubmitted ? Colors.red : Colors.white,
              ),
              onPressed: _reportVideo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerWidget() {
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _isInitialized
              ? Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                )
              : Image.network(
                  widget.video.thumbnailUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                      child: const Icon(Icons.error, color: Colors.white),
                    );
                  },
                ),

          if (_showControls && widget.showControls)
            _buildControls(),

          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          if (_hasError)
            _buildErrorDisplay(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTopControls(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.video.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.allowFullscreen)
            IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: _toggleFullscreen,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isInitialized)
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            colors: const VideoProgressColors(
              playedColor: Colors.blue,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white12,
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: _togglePlay,
              ),
              if (_isInitialized)
                Text(
                  '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                  style: const TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.video.title,
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
                widget.video.formatViews(),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              Text(
                ' • ',
                style: TextStyle(color: Colors.grey[400]),
              ),
              Text(
                widget.video.formatUploadDate(),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              if (widget.video.getQualityInfo().isNotEmpty) ...[
                Text(
                  ' • ',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                Text(
                  widget.video.getQualityInfo(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializePlayer,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}