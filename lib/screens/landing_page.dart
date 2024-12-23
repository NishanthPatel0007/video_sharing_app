import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video.dart';
import '../navigation/app_navigation.dart';
import '../screens/app_footer.dart';
import '../services/auth_service.dart';
import '../services/video_url_service.dart';
import 'login_screen.dart';
import 'public_player_screen.dart';

class LandingPage extends StatefulWidget {
  final String? videoCode;

  const LandingPage({Key? key, this.videoCode}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  Video? _video;
  bool _isLoadingVideo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.videoCode != null) {
      _loadVideo(widget.videoCode!);
    }
  }

  Future<void> _loadVideo(String code) async {
    setState(() {
      _isLoadingVideo = true;
      _error = null;
    });

    try {
      final videoUrlService = VideoUrlService();
      final videoId = await videoUrlService.getVideoId(code);

      if (videoId == null) {
        setState(() {
          _error = 'Video not found';
          _isLoadingVideo = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Video not found';
          _isLoadingVideo = false;
        });
        return;
      }

      setState(() {
        _video = Video.fromFirestore(doc);
        _isLoadingVideo = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading video: $e';
        _isLoadingVideo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1B2C),
      body: Column(
        children: [
          // Navigation Bar
          AppNavigation(
            currentUser: authService.currentUser?.email,
            onLoginPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            onLogoutPressed: () async {
              await authService.signOut();
            },
            onDashboardPressed: () {
              Navigator.pushNamed(context, '/dashboard');
            },
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Video Player Section (if video code exists)
                  if (widget.videoCode != null)
                    Container(
                      height: screenSize.height * (isSmallScreen ? 0.4 : 0.7),
                      width: double.infinity,
                      color: const Color(0xFF2D2940),
                      child: _isLoadingVideo
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : _error != null
                              ? Center(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : _video != null
                                  ? PublicPlayerScreen(video: _video!)
                                  : const Center(
                                      child: Text(
                                        'Video not found',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                    ),

                  // Landing Page Content (only show if no video)
                  if (widget.videoCode == null)
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2940),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Share Your Videos with the World',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Upload, share, and manage your videos easily.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Features Section
                          _buildFeaturesGrid(isSmallScreen),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Footer
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid(bool isSmallScreen) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isSmallScreen ? 1 : 3,
      mainAxisSpacing: 24,
      crossAxisSpacing: 24,
      childAspectRatio: isSmallScreen ? 2 : 1,
      children: const [
        _FeatureCard(
          icon: Icons.upload_file,
          title: 'Easy Upload',
          description: 'Quick and simple video upload process',
        ),
        _FeatureCard(
          icon: Icons.share,
          title: 'Instant Sharing',
          description: 'Share videos with anyone instantly',
        ),
        _FeatureCard(
          icon: Icons.analytics,
          title: 'View Analytics',
          description: 'Track your video performance',
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2940),
        border: Border.all(
          color: const Color(0xFF3D3950),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}