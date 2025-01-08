import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';

import '../models/video.dart';

extension VideoSize on Video {
  double get size => 0.0;
}

class PublicVideoPlayer extends StatefulWidget {
  final Video video;

  const PublicVideoPlayer({
    Key? key,
    required this.video,
  }) : super(key: key);

  @override
  State<PublicVideoPlayer> createState() => _PublicVideoPlayerState();
}

class _PublicVideoPlayerState extends State<PublicVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  double _currentVolume = 1.0;
  Duration _position = Duration.zero;
  bool _isDraggingProgress = false;
  final bool _isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _setupScreen();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.network(widget.video.videoUrl);
      await _controller?.initialize();
      
      _controller?.addListener(() {
        if (!_isDraggingProgress && mounted) {
          setState(() {
            _position = _controller?.value.position ?? Duration.zero;
          });
        }
      });
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }
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

  Widget _buildVideoPlayerWithGestures() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
          if (_showControls && _isPlaying) {
            _startControlsTimer();
          } else {
            _controlsTimer?.cancel();
          }
        });
      },
      child: _buildVideoPlayer(),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_controller!),
          if (_showControls) _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black26,
      child: Stack(
        children: [
          Center(
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                  if (_isPlaying) {
                    _controller?.play();
                    _startControlsTimer();
                  } else {
                    _controller?.pause();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  double _getVideoHeight(BuildContext context) {
    if (_isFullScreen) {
      return MediaQuery.of(context).size.height;
    }
    final width = MediaQuery.of(context).size.width;
    return (width - 32) * 9 / 16;
  }

  Future<bool> _handleBackPress() async {
    if (_isFullScreen) {
      setState(() => _isFullScreen = false);
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controlsTimer?.cancel();
    if (!kIsWeb) {
      Wakelock.disable();
    }
    super.dispose();
  }

  Widget _buildVideoInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          bottom: BorderSide(color: Colors.grey[850]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side - Video Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Size
              Row(
                children: [
                  const Icon(
                    Icons.data_usage,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(widget.video.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Upload Date
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(widget.video.createdAt),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right side - Report Button
          TextButton.icon(
            onPressed: _showReportDialog,
            icon: const Icon(
              Icons.flag_outlined,
              size: 20,
              color: Colors.red,
            ),
            label: const Text(
              'Report',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Report Video',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you reporting this video?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildReportOption('Inappropriate content'),
            _buildReportOption('Copyright violation'),
            _buildReportOption('Violence or harmful content'),
            _buildReportOption('Other'),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return InkWell(
      onTap: () {
        // Handle report submission
        _submitReport(reason);
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          reason,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      // Add report to Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'videoId': widget.video.id,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for reporting. We will review this video.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _getMonth(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Column(
            children: [
              // App Bar
              AppBar(
                backgroundColor: const Color(0xFF121212),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'For10Cloud Shared',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Video Player
              Container(
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

              // Video Info with Report Button
              _buildVideoInfo(),
            ],
          ),
        ),
      ),
    );
  }
} 