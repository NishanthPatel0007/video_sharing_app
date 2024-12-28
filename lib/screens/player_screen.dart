import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import '../models/view_level.dart';
import '../services/storage_service.dart';

class PlayerScreen extends StatefulWidget {
  final Video video;
  
  const PlayerScreen({Key? key, required this.video}) : super(key: key);

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
  Timer? _viewCountTimer;
  bool _viewCounted = false;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _startViewCountTimer();
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
      }
    } catch (e) {
      print('Video initialization error: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        _showErrorSnackbar('Error loading video: $e');
      }
    }
  }

  void _videoListener() {
    final isBuffering = _controller.value.isBuffering;
    if (_isBuffering != isBuffering && mounted) {
      setState(() => _isBuffering = isBuffering);
    }

    // Count view when video plays for at least 5 seconds
    if (!_viewCounted && 
        _controller.value.position >= const Duration(seconds: 5)) {
      _countView();
    }
  }

  void _startViewCountTimer() {
    _viewCountTimer = Timer(const Duration(seconds: 5), () {
      if (_controller.value.isPlaying && !_viewCounted) {
        _countView();
      }
    });
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
          '🎉 Milestone Achieved!',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${level.displayText}\nReward: ${ViewLevel.formatReward(level.rewardAmount)}',
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

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _initializeVideo,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _viewCountTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: Stack(
                        children: [
                          VideoPlayer(_controller),
                          _VideoControls(
                            controller: _controller,
                            isFullScreen: _isFullScreen,
                            onToggleFullScreen: _toggleFullScreen,
                          ),
                          if (_isBuffering)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
            if (!_isFullScreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
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
                style: const TextStyle(color: Colors.white),
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
      ),
    );
  }
}

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
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_isDragging) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && widget.controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
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
        final duration = value.duration;
        final position = value.position;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    _isDragging = true;
                    setState(() => _showControls = true);
                  },
                  onHorizontalDragEnd: (_) {
                    _isDragging = false;
                    _startHideTimer();
                  },
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final dx = details.localPosition.dx;
                    final width = box.size.width;
                    final percentage = dx / width;
                    final position = duration * percentage;
                    widget.controller.seekTo(position);
                  },
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 2,
                          color: Colors.white24,
                        ),
                        Container(
                          height: 2,
                          width: MediaQuery.of(context).size.width *
                              (position.inMilliseconds /
                                  duration.inMilliseconds),
                          color: Colors.white,
                        ),
                      ],
                    ),
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
              widget.controller.seekTo(position - const Duration(seconds: 10));
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
              widget.controller.seekTo(position + const Duration(seconds: 10));
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

// Mobile Browser Detection Helper
class _BrowserHelper {
  static bool get isMobileBrowser {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('mobile') || 
           userAgent.contains('android') || 
           userAgent.contains('iphone');
  }

  static bool get isSafari {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('safari') && !userAgent.contains('chrome');
  }

  static bool get isIOS {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') || 
           userAgent.contains('ipad') || 
           userAgent.contains('ipod');
  }

  static Map<String, String> getVideoHeaders() {
    if (isIOS) {
      return {
        'Accept-Ranges': 'bytes',
        'Access-Control-Allow-Origin': '*',
        'Range': 'bytes=0-',
      };
    }
    return {
      'Accept-Ranges': 'bytes',
      'Access-Control-Allow-Origin': '*',
    };
  }
}

// Custom Video Progress Indicator
class _CustomVideoProgressIndicator extends StatelessWidget {
  final VideoPlayerController controller;
  final bool allowScrubbing;
  final Color backgroundColor;
  final Color progressColor;

  const _CustomVideoProgressIndicator(
    this.controller, {
    this.allowScrubbing = true,
    this.backgroundColor = const Color(0x5A000000),
    this.progressColor = const Color(0xFF8257E5),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, VideoPlayerValue value, child) {
        if (value.duration == Duration.zero) {
          return const SizedBox();
        }

        return GestureDetector(
          onHorizontalDragStart: allowScrubbing ? (DragStartDetails details) {
            controller.pause();
          } : null,
          onHorizontalDragUpdate: allowScrubbing ? (DragUpdateDetails details) {
            final box = context.findRenderObject() as RenderBox;
            final Offset localPosition = box.globalToLocal(details.globalPosition);
            final double progress = localPosition.dx / box.size.width;
            controller.seekTo(value.duration * progress);
          } : null,
          onHorizontalDragEnd: allowScrubbing ? (DragEndDetails details) {
            controller.play();
          } : null,
          onTapDown: allowScrubbing ? (TapDownDetails details) {
            final box = context.findRenderObject() as RenderBox;
            final Offset localPosition = box.globalToLocal(details.globalPosition);
            final double progress = localPosition.dx / box.size.width;
            controller.seekTo(value.duration * progress);
          } : null,
          child: Stack(
            children: [
              Container(
                height: 4.0,
                color: backgroundColor,
              ),
              FractionallySizedBox(
                widthFactor: value.position.inMilliseconds / 
                            value.duration.inMilliseconds,
                child: Container(
                  height: 4.0,
                  color: progressColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Video Error Widget
class _VideoErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _VideoErrorWidget({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8257E5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}