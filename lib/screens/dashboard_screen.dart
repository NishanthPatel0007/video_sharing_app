import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/video.dart';
import '../services/storage_service.dart';
import 'upload_video_screen.dart';
import 'video_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StorageService _storage = StorageService();
  final _auth = FirebaseAuth.instance;
  List<Video> _videos = [];
  bool _isLoading = true;
  String? _error;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final videos = await _storage.getUserVideos();
      if (mounted) {
        setState(() {
          _videos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load videos: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshVideos() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      final videos = await _storage.getUserVideos();
      if (mounted) {
        setState(() {
          _videos = videos;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _deleteVideo(String videoId) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text(
          'Are you sure you want to delete this video? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await _storage.deleteVideo(videoId);
      await _loadVideos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete video: $e')),
        );
      }
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadVideos,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Videos'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_auth.currentUser?.email ?? ''),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Upload Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
                  );
                  if (result == true) {
                    _loadVideos();
                  }
                },
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload New Video'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          // Videos Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _videos.isEmpty
                        ? const Center(child: Text('No videos uploaded yet'))
                        : RefreshIndicator(
                            onRefresh: _refreshVideos,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 16 / 11,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _videos.length,
                              itemBuilder: (context, index) => _buildVideoCard(_videos[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(Video video) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoDetailsScreen(
                video: video,
                onDelete: () => _deleteVideo(video.id),
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Duration
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      );
                    },
                  ),
                ),
                // Duration badge
                if (video.metadata != null && video.metadata!.containsKey('duration'))
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.formatDuration(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                // Quality badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.getQualityInfo(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Video Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        video.formatViews(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          video.formatUploadDate(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}