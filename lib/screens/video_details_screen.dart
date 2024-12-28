import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/video.dart';
import '../models/view_level.dart';
import '../screens/player_screen.dart';
import '../services/storage_service.dart';
import '../services/video_url_service.dart';
import '../widgets/view_milestone_widget.dart';

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
  final StorageService _storage = StorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isGeneratingUrl = false;
  bool _isProcessingClaim = false;
  String? _shareUrl;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadShareUrl();
  }

  Future<void> _loadShareUrl() async {
    try {
      final url = await _urlService.getShareUrl(widget.video.id);
      if (mounted) {
        setState(() => _shareUrl = url);
      }
    } catch (e) {
      debugPrint('Error loading share URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load share URL: $e')),
        );
      }
    }
  }

  Future<void> handleMilestoneClaim(int level, double amount) async {
    if (_isProcessingClaim) return;

    setState(() => _isProcessingClaim = true);
    try {
      // First check if payment details exist
      final paymentDetails = await _storage.getPaymentDetails();
      if (paymentDetails == null || !paymentDetails.isComplete) {
        _showPaymentDetailsDialog();
        return;
      }

      await _storage.processMilestoneClaim(
        videoId: widget.video.id,
        level: level,
        amount: amount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone claimed successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Milestone claim error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim milestone: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingClaim = false);
    }
  }

  void _showPaymentDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2940),
        title: const Text(
          'Payment Details Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please add your payment details before claiming rewards.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/payment-settings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8257E5),
            ),
            child: const Text('Add Details'),
          ),
        ],
      ),
    );
  }
  

  Future<void> _confirmDelete() async {
    if (_isDeleting) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2940),
        title: const Text(
          'Delete Video',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this video?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            if (widget.video.totalEarnings > 0) ...[
              const Text(
                'Warning: All unclaimed rewards will be lost.',
                style: TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Earnings: ${ViewLevel.formatReward(widget.video.totalEarnings)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              setState(() => _isDeleting = true);
              Navigator.pop(context);
              
              try {
                await widget.onDelete();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete video: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isDeleting = false);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
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
      backgroundColor: const Color(0xFF1E1B2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2C),
        title: const Text(
          'Video Details',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (FirebaseAuth.instance.currentUser?.uid == widget.video.userId)
            IconButton(
              icon: _isDeleting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.red,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.delete, color: Colors.white),
              onPressed: _isDeleting ? null : _confirmDelete,
              tooltip: 'Delete Video',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Section
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2940),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlayerScreen(video: widget.video),
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
                              color: const Color(0xFF2D2940),
                              child: const Icon(Icons.error, color: Colors.white),
                            );
                          },
                        ),
                        Container(
                          color: Colors.black.withOpacity(0.3),
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
              ),
            ),

            // Title and Views Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2940),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        widget.video.getFormattedViews(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '•',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(widget.video.createdAt),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // User Info Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2940),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      (widget.video.userEmail ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.userEmail ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Uploader',
                            style: TextStyle(color: Colors.white70),
                          ),
                          if (widget.video.totalEarnings > 0) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'Earned ${ViewLevel.formatReward(widget.video.totalEarnings)}',
                              style: const TextStyle(
                                color: Color(0xFF8257E5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Share URL Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2940),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SHARE VIDEO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3D3950),
                        width: 1,
                      ),
                    ),
                    child: SelectableText(
                      _shareUrl ?? 'https://for10cloud.com/v/...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isGeneratingUrl
                        ? null
                        : () async {
                            setState(() => _isGeneratingUrl = true);
                            try {
                              await _urlService.copyToClipboard(
                                widget.video.id,
                                context,
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isGeneratingUrl = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8257E5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                   // Fix this part in the Share URL Section
                      child: _isGeneratingUrl
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.content_copy,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Copy Link',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            
            // View Milestone Widget
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2940),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'View Milestones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.video.getRemainingClaimableAmount() > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8257E5).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF8257E5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Available: ${ViewLevel.formatReward(widget.video.getRemainingClaimableAmount())}',
                              style: const TextStyle(
                                color: Color(0xFF8257E5),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ViewMilestoneWidget(
                      views: widget.video.views,
                      lastClaimedLevel: widget.video.lastClaimedLevel,
                      onClaimPressed: handleMilestoneClaim,
                      isProcessingClaim: _isProcessingClaim,
                      claimedMilestones: widget.video.claimedMilestones,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}