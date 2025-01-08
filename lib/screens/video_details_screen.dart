import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';

import '../models/video.dart';
import '../services/video_url_service.dart';

class VideoDetailsScreen extends StatefulWidget {
  final Video video;
  final Function() onDelete;

  const VideoDetailsScreen({
    Key? key,
    required this.video,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen> {
  final VideoUrlService _urlService = VideoUrlService();
  bool _isGeneratingUrl = false;
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  double _currentVolume = 1.0;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  bool _isDraggingProgress = false;
  Timer? _forwardingTimer;
  Timer? _rewindingTimer;
  bool _showVolumeSlider = false;
  double _videoScreenBrightness = 0.0;
  bool _isLocked = false;
  double _dragStartPos = 0.0;
  double _dragStartTime = 0.0;
  bool _isDragging = false;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;
  final bool _isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  String? _shareUrl;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _setupScreen();
    _generateShareUrl();
  }

  Future<void> _setupScreen() async {
    try {
      if (!kIsWeb) {
        await Wakelock.enable();
      }
      
      if (_isMobile) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } catch (e) {
      debugPrint('Error setting up screen: $e');
    }
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.network(widget.video.videoUrl);
      await _controller?.initialize();
      
      _controller?.addListener(() {
        if (!_isDraggingProgress && mounted) {
          setState(() {
            _position = _controller?.value.position ?? Duration.zero;
            _bufferedPosition = _controller?.value.buffered.isNotEmpty == true
                ? _controller!.value.buffered.last.end
                : Duration.zero;
          });
        }
      });
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: $e')),
        );
      }
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _controller?.play();
        if (_showControls) {
          _startControlsTimer();
        }
      } else {
        _controller?.pause();
        _showControls = true;
        _controlsTimer?.cancel();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      if (_showVolumeSlider) {
        _isMuted = !_isMuted;
        _controller?.setVolume(_isMuted ? 0 : _currentVolume);
      }
      _showVolumeSlider = !_showVolumeSlider;
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isMobile) {
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
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  void _changePlaybackSpeed() {
    final speeds = [0.5, 1.0, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    setState(() {
      _playbackSpeed = speeds[nextIndex];
      _controller?.setPlaybackSpeed(_playbackSpeed);
    });
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Black background for letterboxing
        Container(color: Colors.black),
        
        // Video player with aspect ratio
        Center(
          child: AspectRatio(
            aspectRatio: _isFullScreen 
                ? MediaQuery.of(context).size.width / MediaQuery.of(context).size.height 
                : _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        
        if (_showControls) _buildControls(),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black26,
      child: Stack(
        children: [
          // Center Play Button
          Center(
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 64,
                color: Colors.white,
              ),
              onPressed: _togglePlayPause,
            ),
          ),
          
          // Bottom Controls Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              children: [
                // Progress Bar
                SliderTheme(
                  data: SliderThemeData(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _controller?.value.duration.inSeconds.toDouble() ?? 0.0,
                    onChanged: (value) {
                      setState(() {
                        _position = Duration(seconds: value.toInt());
                        _isDraggingProgress = true;
                      });
                    },
                    onChangeEnd: (value) {
                      _controller?.seekTo(Duration(seconds: value.toInt()));
                      setState(() => _isDraggingProgress = false);
                    },
                  ),
                ),
                
                // Controls Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // Play/Pause Button
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      // Volume Control
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white,
                            ),
                            onPressed: _toggleMute,
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _showVolumeSlider ? 100 : 0,
                            child: _showVolumeSlider ? SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                              ),
                              child: Slider(
                                value: _currentVolume,
                                onChanged: (value) {
                                  setState(() {
                                    _currentVolume = value;
                                    _controller?.setVolume(value);
                                    _isMuted = value == 0;
                                  });
                                },
                              ),
                            ) : null,
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Fullscreen Button
                      IconButton(
                        icon: Icon(
                          _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullScreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _forwardVideo() {
    final newPosition = _controller!.value.position + const Duration(seconds: 10);
    _controller?.seekTo(newPosition);
    setState(() {
      _forwardingTimer?.cancel();
      _forwardingTimer = Timer(const Duration(milliseconds: 500), () {
        setState(() => _forwardingTimer = null);
      });
    });
  }

  void _rewindVideo() {
    final newPosition = _controller!.value.position - const Duration(seconds: 10);
    _controller?.seekTo(newPosition);
    setState(() {
      _rewindingTimer?.cancel();
      _rewindingTimer = Timer(const Duration(milliseconds: 500), () {
        setState(() => _rewindingTimer = null);
      });
    });
  }

  Future<void> _confirmDelete(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text(
          'Are you sure you want to delete this video? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
              Navigator.pop(context); // Return to dashboard
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildVideoPlayerWithGestures() {
    return GestureDetector(
      onTap: _isLocked ? null : () {
        setState(() {
          _showControls = !_showControls;
          if (_showControls && _isPlaying) {
            _startControlsTimer();
          } else {
            _controlsTimer?.cancel();
          }
        });
      },
      onHorizontalDragStart: _isLocked ? null : (details) {
        setState(() {
          _isDragging = true;
          _dragStartPos = details.globalPosition.dx;
          _dragStartTime = _position.inSeconds.toDouble();
        });
      },
      onHorizontalDragUpdate: _isLocked ? null : (details) {
        if (!_isDragging) return;
        
        final dragDist = details.globalPosition.dx - _dragStartPos;
        final screenWidth = MediaQuery.of(context).size.width;
        final dragPercent = dragDist / screenWidth;
        final videoDuration = _controller!.value.duration.inSeconds.toDouble();
        final newTime = _dragStartTime + (dragPercent * videoDuration);
        
        setState(() {
          _position = Duration(seconds: newTime.toInt().clamp(0, videoDuration.toInt()));
        });
      },
      onHorizontalDragEnd: _isLocked ? null : (details) {
        if (!_isDragging) return;
        _controller?.seekTo(_position);
        setState(() => _isDragging = false);
      },
      onVerticalDragUpdate: _isLocked ? null : (details) {
        final isRightSide = details.globalPosition.dx > MediaQuery.of(context).size.width / 2;
        final sensitivity = 0.01;
        final change = details.delta.dy * sensitivity;

        if (isRightSide) {
          // Volume control
          setState(() {
            _currentVolume = (_currentVolume - change).clamp(0.0, 1.0);
            _controller?.setVolume(_currentVolume);
            _showVolumeIndicator = true;
            _indicatorTimer?.cancel();
            _indicatorTimer = Timer(const Duration(seconds: 2), () {
              setState(() => _showVolumeIndicator = false);
            });
          });
        } else {
          // Brightness control
          setState(() {
            _videoScreenBrightness = (_videoScreenBrightness - change).clamp(0.0, 1.0);
            _showBrightnessIndicator = true;
            _indicatorTimer?.cancel();
            _indicatorTimer = Timer(const Duration(seconds: 2), () {
              setState(() => _showBrightnessIndicator = false);
            });
          });
        }
      },
      child: Stack(
        children: [
          _buildVideoPlayer(),
          
          // Lock Button
          if (_showControls)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: Icon(
                  _isLocked ? Icons.lock : Icons.lock_open,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() => _isLocked = !_isLocked);
                },
              ),
            ),

          // Volume Indicator
          if (_showVolumeIndicator)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height / 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
        child: Column(
          children: [
                    Icon(
                      _currentVolume == 0
                          ? Icons.volume_off
                          : _currentVolume < 0.5
                              ? Icons.volume_down
                              : Icons.volume_up,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_currentVolume * 100).round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Brightness Indicator
          if (_showBrightnessIndicator)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height / 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.brightness_6, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      '${(_videoScreenBrightness * 100).round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Seeking Indicator
          if (_isDragging)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDuration(_position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Stats
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                    fontSize: 20,
                      fontWeight: FontWeight.bold,
                    color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${widget.video.views} views',
                        style: TextStyle(
                        color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                      style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(widget.video.createdAt),
                        style: TextStyle(
                        color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF2A2A2A)),
        ],
      ),
    );
  }

  Widget _buildUploaderInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
                    children: [
                      CircleAvatar(
            backgroundColor: Colors.grey[800],
                        child: Text(
                          (widget.video.userEmail ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
          Expanded(
            child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.video.userEmail ?? 'Unknown User',
                            style: const TextStyle(
                              fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Uploader',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generateShareUrl() async {
    try {
      final url = await _urlService.getShareUrl(widget.video.id);
      if (mounted) {
        setState(() => _shareUrl = url);
      }
    } catch (e) {
      debugPrint('Error generating share URL: $e');
    }
  }

  Widget _buildShareSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
              'SHARE VIDEO',
                      style: TextStyle(
                fontSize: 16,
                        fontWeight: FontWeight.bold,
                color: Colors.white,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
            const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                vertical: 12,
                      ),
                      decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(4),
                      ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(
                      _shareUrl ?? 'Generating URL...',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _shareUrl == null || _isGeneratingUrl
                  ? null
                  : () => _urlService.copyToClipboard(widget.video.id, context),
              icon: _isGeneratingUrl
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(Icons.copy, size: 20),
              label: Text(
                _isGeneratingUrl ? 'COPYING...' : 'COPY',
                style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                disabledBackgroundColor: Colors.grey[700],
                disabledForegroundColor: Colors.grey[400],
              ),
            ),
            if (!kIsWeb && _shareUrl != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Share.share(
                    _shareUrl!,
                    subject: 'Check out this video',
                  );
                },
                icon: const Icon(Icons.share, color: Colors.white70),
                label: const Text(
                  'SHARE WITH OTHERS',
                  style: TextStyle(color: Colors.white70),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Fixed AppBar
              SliverAppBar(
                backgroundColor: const Color(0xFF121212),
                pinned: true,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Video Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () => _confirmDelete(context),
                    tooltip: 'Delete Video',
                  ),
                ],
              ),

              // Video Player Section (Fixed when scrolling)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: _getVideoHeight(context),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(_isFullScreen ? 0 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildVideoPlayerWithGestures(),
                ),
              ),

              // Scrollable Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVideoInfo(),
                    _buildUploaderInfo(),
                    _buildShareSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getVideoHeight(BuildContext context) {
    if (_isFullScreen) {
      return MediaQuery.of(context).size.height;
    }
    final width = MediaQuery.of(context).size.width;
    // Account for margins (32px total)
    return (width - 32) * 9 / 16;
  }

  Future<bool> _handleBackPress() async {
    if (_isFullScreen) {
      _toggleFullScreen();
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    try {
      if (!kIsWeb) {
        Wakelock.disable();
      }
      if (_isMobile) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      _controller?.dispose();
      _controlsTimer?.cancel();
      _indicatorTimer?.cancel();
    } catch (e) {
      debugPrint('Error in dispose: $e');
    }
    super.dispose();
  }
}