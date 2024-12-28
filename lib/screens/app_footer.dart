// lib/widgets/app_footer.dart
import 'package:flutter/material.dart';

import '../models/view_level.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,  // Reduced padding
        vertical: isSmallScreen ? 12 : 16,    // Reduced padding
      ),
      color: const Color(0xFF2D2940),
      child: Column(
        mainAxisSize: MainAxisSize.min,  // Added to reduce height
        children: [
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
                            padding: const EdgeInsets.all(6), // Reduced padding
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 18,  // Reduced size
                            ),
                          ),
                          const SizedBox(width: 8),  // Reduced spacing
                          const Text(
                            'For10Cloud',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,  // Reduced font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),  // Reduced spacing
                      const Text(
                        'Share your videos and earn rewards based on views.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,  // Reduced font size
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
                          fontSize: 14,  // Reduced font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),  // Reduced spacing
                      ...ViewLevel.levels
                          .where((level) => level.rewardAmount > 0)
                          .map((level) => Padding(
                                padding: const EdgeInsets.only(bottom: 4), // Reduced padding
                                child: Text(
                                  '${level.displayText}: ${ViewLevel.formatReward(level.rewardAmount)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,  // Reduced font size
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
                        fontSize: 14,  // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),  // Reduced spacing
                    _buildFooterLink('Upload Video', onTap: () => Navigator.pushNamed(context, '/dashboard')),
                    _buildFooterLink('My Videos', onTap: () => Navigator.pushNamed(context, '/dashboard')),
                    _buildFooterLink('Help Center', onTap: () => _showComingSoon(context)),
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
                          fontSize: 14,  // Reduced font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),  // Reduced spacing
                      _buildFooterLink('Contact Us'),
                      _buildFooterLink('FAQ'),
                      _buildFooterLink('Terms of Service'),
                      _buildFooterLink('Privacy Policy'),
                    ],
                  ),
                ),
            ],
          ),

          if (!isSmallScreen) const SizedBox(height: 24),  // Reduced spacing

          // Bottom Bar
          Container(
            padding: const EdgeInsets.only(top: 12),  // Reduced padding
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '© ${DateTime.now().year} For10Cloud. All rights reserved.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,  // Reduced font size
                  ),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(vertical: 4),  // Reduced padding
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,  // Reduced font size
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    // ... rest of the code remains the same
  }
}