import 'package:flutter/material.dart';
import 'package:video_sharing_app_new/screens/login_screen.dart';

class LandingScreen extends StatelessWidget {
  final bool isTransitioning;
  final String? transitionMessage;

  const LandingScreen({
    Key? key, 
    this.isTransitioning = false,
    this.transitionMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111827), Color(0xFF1F2937)],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  // Navigation Bar
                  _buildNavigationBar(context),
                  
                  // Hero Section
                  _buildHeroSection(context),
                  
                  // Features Section
                  _buildFeaturesSection(),
                  
                  // Footer
                  _buildFooter(),
                ],
              ),
            ),
            
            // Transition Overlay
            if (isTransitioning)
              _buildTransitionOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'For10Cloud',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(minHeight: 500),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Share Videos Effortlessly',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const Text(
              'Upload, share, and manage your videos with ease. Get instant shareable links and reach your audience quickly.',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth > 800
                  ? _buildFeaturesGrid()
                  : _buildFeaturesColumn();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Colors.blue[400]),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.cloud_upload,
            title: 'Easy Upload',
            description: 'Upload your videos with simple drag and drop functionality.',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.share,
            title: 'Instant Sharing',
            description: 'Get shareable links instantly for your uploaded videos.',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.video_library,
            title: 'Video Management',
            description: 'Manage all your videos from a simple dashboard interface.',
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesColumn() {
    return Column(
      children: [
        _buildFeatureCard(
          icon: Icons.cloud_upload,
          title: 'Easy Upload',
          description: 'Upload your videos with simple drag and drop functionality.',
        ),
        const SizedBox(height: 24),
        _buildFeatureCard(
          icon: Icons.share,
          title: 'Instant Sharing',
          description: 'Get shareable links instantly for your uploaded videos.',
        ),
        const SizedBox(height: 24),
        _buildFeatureCard(
          icon: Icons.video_library,
          title: 'Video Management',
          description: 'Manage all your videos from a simple dashboard interface.',
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Text(
        '© 2025 For10Cloud. All rights reserved.',
        style: TextStyle(
          color: Colors.white54,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTransitionOverlay(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 24),
            if (transitionMessage != null)
              Text(
                transitionMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}