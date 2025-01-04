import 'dart:async';

import 'package:flutter/material.dart';

import '../models/video.dart';
import '../services/video_url_service.dart';
import 'player_screen.dart';

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
              Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Delete Video',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail with Play Button
            AspectRatio(
              aspectRatio: 16 / 9,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerScreen(
                        video: widget.video,
                        onBack: () => Navigator.pop(context), // Fixed: Added onBack
                      ),
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      widget.video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        );
                      },
                    ),
                    Container(
                      color: Colors.black.withOpacity(0.2),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Video Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${widget.video.views} views',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(widget.video.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Share Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isGeneratingUrl
                          ? null
                          : () async {
                              setState(() => _isGeneratingUrl = true);
                              await _urlService.copyToClipboard(
                                widget.video.id,
                                context,
                              );
                              setState(() => _isGeneratingUrl = false);
                            },
                      child: _isGeneratingUrl
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(),
                            )
                          : const Text('Copy Share Link'),
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
}