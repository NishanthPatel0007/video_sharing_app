import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video.dart';
import '../navigation/app_navigation.dart';
import '../screens/app_footer.dart';
import '../screens/public_player_screen.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/video_url_service.dart';
import 'login_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  Video? _video;
  bool _isLoadingVideo = false;
  String? _error;
  final StorageService _storage = StorageService();
  final VideoUrlService _urlService = VideoUrlService();

  @override
  void initState() {
    super.initState();
    _checkVideoParam();
  }

  void _checkVideoParam() {
    // Check both URL formats
    final uri = Uri.parse(html.window.location.href);
    String? videoCode;
    
    // Check path format (/v/CODE)
    if (uri.path.startsWith('/v/')) {
      videoCode = uri.path.substring(3);
    }
    // Check query parameter format (?video=CODE)
    else if (uri.queryParameters.containsKey('video')) {
      videoCode = uri.queryParameters['video'];
    }

    if (videoCode != null) {
      _loadVideo(videoCode);
    }
  }

  Future<void> _loadVideo(String code) async {
    if (!mounted) return;

    setState(() {
      _isLoadingVideo = true;
      _error = null;
    });

    try {
      final videoId = await _urlService.getVideoId(code);

      if (videoId == null) {
        if (mounted) {
          setState(() {
            _error = 'Video not found';
            _isLoadingVideo = false;
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          setState(() {
            _error = 'Video not found';
            _isLoadingVideo = false;
          });
        }
        return;
      }

      // Increment views
      await _storage.incrementViews(videoId);

      if (mounted) {
        setState(() {
          _video = Video.fromFirestore(doc);
          _isLoadingVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading video: $e';
          _isLoadingVideo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    // Show video player if video is loaded
    if (_video != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1B2C),
        body: Column(
          children: [
            AppNavigation(
              currentUser: authService.currentUser?.email,
              onLoginPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              ),
              onLogoutPressed: () async => await authService.signOut(),
              onDashboardPressed: () => Navigator.pushNamed(context, '/dashboard'),
            ),
            Expanded(
              child: PublicVideoPage(
                videoCode: Uri.parse(html.window.location.href)
                    .queryParameters['video'] ?? '',
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1B2C),
      body: Column(
        children: [
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (_isLoadingVideo)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8257E5)),
                      ),
                    )
                  else if (_error != null)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _checkVideoParam,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8257E5),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                      child: Column(
                        children: [
                          _buildWelcomeSection(),
                          const SizedBox(height: 48),
                          _buildFeaturesGrid(isSmallScreen),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2940),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text(
            'Share Your Videos with the World',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Upload, share, and manage your videos easily.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
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