import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import '../services/storage_service.dart';

class PlayerScreen extends StatefulWidget {
  final Video video;
  final bool autoPlay;  // New parameter for auto-play
  
  const PlayerScreen({
    Key? key, 
    required this.video, 
    this.autoPlay = true,  // Default to true
  }) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _isFullScreen = false;
  bool _hasError = false;
  String _errorMessage = '';
  final StorageService _storage = StorageService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _initializeVideo();
    _incrementViews();
  }

  Future<void> _initializeVideo() async {
    setState(() => _isBuffering = true);
    try {
      _controller = VideoPlayerController.network(
        widget.video.videoUrl,
        httpHeaders: {
          'Accept-Ranges': 'bytes',
          'Access-Control-Allow-Origin': '*',
        },
      );

      await _controller.initialize();
      _controller.addListener(_videoListener);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isBuffering = false;
          _hasError = false;
        });
        
        // Start fade-in animation
        _fadeController.forward();
        
        // Auto-play if enabled
        if (widget.autoPlay) {
          _controller.play();
        }
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _initializeVideo,
            ),
          ),
        );
      }
    }
  }

  void _videoListener() {
    final isBuffering = _controller.value.isBuffering;
    if (_isBuffering != isBuffering && mounted) {
      setState(() => _isBuffering = isBuffering);
    }
  }

  Future<void> _incrementViews() async {
    try {
      await _storage.incrementViews(widget.video.id);
    } catch (e) {
      print('Failed to increment views: $e');
    }
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _isFullScreen ? null : AppBar(
          title: Text(widget.video.title),
          actions: [
            IconButton(
              icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
              onPressed: _toggleFullScreen,
            ),
          ],
        ),
        body: _hasError ? _buildErrorWidget() : _buildVideoPlayer(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading video: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initializeVideo,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
          });
        },
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            _VideoControls(
              controller: _controller,
              isFullScreen: _isFullScreen,
              onToggleFullScreen: _toggleFullScreen,
            ),
          ],
        ),
      ),
    );
  }
}

// Keep existing _VideoControls class unchanged
class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;

  const _VideoControls({
    Key? key,
    required this.controller,
    required this.isFullScreen,
    required this.onToggleFullScreen,
  }) : super(key: key);

  @override
  _VideoControlsState createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
        if (_showControls) _startHideTimer();
      },
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
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
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTopBar(),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              widget.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: widget.onToggleFullScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProgressBar(),
        _buildControlButtons(),
      ],
    );
  }

  Widget _buildProgressBar() {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, VideoPlayerValue value, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                _formatDuration(value.position),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  value: value.position.inMilliseconds.toDouble(),
                  min: 0.0,
                  max: value.duration.inMilliseconds.toDouble(),
                  onChanged: (position) {
                    widget.controller.seekTo(Duration(
                      milliseconds: position.toInt(),
                    ));
                  },
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

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white),
            onPressed: () {
              final position = widget.controller.value.position;
              widget.controller.seekTo(
                position - const Duration(seconds: 10),
              );
              _startHideTimer();
            },
          ),
          ValueListenableBuilder(
            valueListenable: widget.controller,
            builder: (context, VideoPlayerValue value, child) {
              return IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
                onPressed: () {
                  value.isPlaying
                      ? widget.controller.pause()
                      : widget.controller.play();
                  _startHideTimer();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.forward_10, color: Colors.white),
            onPressed: () {
              final position = widget.controller.value.position;
              widget.controller.seekTo(
                position + const Duration(seconds: 10),
              );
              _startHideTimer();
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}