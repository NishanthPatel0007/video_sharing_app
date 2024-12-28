// lib/widgets/app_footer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/view_level.dart';
import '../services/auth_service.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final authService = Provider.of<AuthService>(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 16 : 24,
      ),
      color: const Color(0xFF2D2940),
      child: Column(
        children: [
          // Main Footer Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo and About Section
              if (!isSmallScreen)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF8257E5),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'For10Cloud',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Share your videos and earn rewards based on views.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

              // Milestone Information
              if (!isSmallScreen)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Milestones',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...ViewLevel.levels
                          .where((level) => level.rewardAmount > 0)
                          .map((level) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${level.displayText}: ${ViewLevel.formatReward(level.rewardAmount)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              )),
                    ],
                  ),
                ),

              // Quick Links
              Expanded(
                flex: isSmallScreen ? 1 : 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Links',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFooterLink(
                      'Upload Video',
                      onTap: () => Navigator.pushNamed(context, '/dashboard'),
                    ),
                    _buildFooterLink(
                      'My Videos',
                      onTap: () => Navigator.pushNamed(context, '/dashboard'),
                    ),
                    if (authService.currentUser != null)
                      _buildFooterLink(
                        'Payment Settings',
                        onTap: () => Navigator.pushNamed(context, '/payment-settings'),
                      ),
                    _buildFooterLink(
                      'Help Center',
                      onTap: () => _showComingSoon(context),
                    ),
                  ],
                ),
              ),

              // Support Section
              if (!isSmallScreen)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Support',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFooterLink(
                        'Contact Us',
                        onTap: () => _launchEmail('support@for10cloud.com'),
                      ),
                      _buildFooterLink(
                        'FAQ',
                        onTap: () => _showComingSoon(context),
                      ),
                      _buildFooterLink(
                        'Terms of Service',
                        onTap: () => _showTerms(context),
                      ),
                      _buildFooterLink(
                        'Privacy Policy',
                        onTap: () => _showPrivacy(context),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (!isSmallScreen) const SizedBox(height: 48),

          // Bottom Bar
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© ${DateTime.now().year} For10Cloud. All rights reserved.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  if (!isSmallScreen)
                    Row(
                      children: [
                        _buildSocialLink(
                          Icons.facebook,
                          onTap: () => _launchURL('https://facebook.com/for10cloud'),
                        ),
                        _buildSocialLink(
                          Icons.telegram,
                          onTap: () => _launchURL('https://t.me/for10cloud'),
                        ),
                        _buildSocialLink(
                          Icons.discord,
                          onTap: () => _launchURL('https://discord.gg/for10cloud'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLink(IconData icon, {VoidCallback? onTap}) {
    return IconButton(
      icon: Icon(icon),
      color: Colors.white70,
      onPressed: onTap,
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2940),
        title: const Text(
          'Coming Soon',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This feature is coming soon!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2940),
        title: const Text(
          'Terms of Service',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTermsSection(
                'Milestone Rewards',
                'Users earn rewards based on video view milestones. Each milestone has a specific reward amount. Rewards are subject to verification.',
              ),
              _buildTermsSection(
                'Payment Processing',
                'Payments are processed within 24-48 hours after claiming a milestone. Valid payment details must be provided.',
              ),
              _buildTermsSection(
                'Content Guidelines',
                'Users must upload appropriate content. Violation of guidelines may result in account suspension.',
              ),
              _buildTermsSection(
                'View Verification',
                'Views are verified for authenticity. Artificial views may result in milestone claim rejection.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    // Similar to _showTerms but with privacy content
  }

  void _launchEmail(String email) async {
    final url = 'mailto:$email';
    // Implement URL launcher
  }

  void _launchURL(String url) {
    // Implement URL launcher
  }
}