// lib/navigation/app_navigation.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/view_level.dart';
import '../services/auth_service.dart';

class AppNavigation extends StatelessWidget {
  final String? currentUser;
  final VoidCallback onLoginPressed;
  final VoidCallback? onLogoutPressed;
  final VoidCallback? onDashboardPressed;

  const AppNavigation({
    Key? key,
    this.currentUser,
    required this.onLoginPressed,
    this.onLogoutPressed,
    this.onDashboardPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navHeight = MediaQuery.of(context).size.height * 0.08;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final authService = Provider.of<AuthService>(context);

    return Container(
      height: navHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2C),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and Brand
          InkWell(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            child: Row(
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
                if (!isSmallScreen) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'For10Cloud',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right Side Navigation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentUser != null) ...[
                // Earnings Display
                if (!isSmallScreen)
                  FutureBuilder<Map<String, dynamic>>(
                    future: authService.getUserStats(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final stats = snapshot.data!;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2940),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF8257E5),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Earnings',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    ViewLevel.formatReward(
                                      stats['totalEarnings'].toDouble()
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                const SizedBox(width: 16),

                // Dashboard Button
                if (!isSmallScreen)
                  TextButton.icon(
                    onPressed: onDashboardPressed,
                    icon: const Icon(
                      Icons.dashboard,
                      color: Colors.white70,
                    ),
                    label: const Text(
                      'Dashboard',
                      style: TextStyle(color: Colors.white70),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),

                // User Menu
                _buildUserMenu(context),
              ] else
                // Login Button
                ElevatedButton(
                  onPressed: onLoginPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8257E5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isSmallScreen ? 'Login' : 'Sign In',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      color: const Color(0xFF2D2940),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF8257E5),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white24,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Text(
              currentUser?.isNotEmpty == true 
                  ? currentUser![0].toUpperCase() 
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_drop_down,
            color: Colors.white70,
          ),
        ],
      ),
      itemBuilder: (context) => [
        // User Email
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 20,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                currentUser ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),

        // Dashboard Option
        PopupMenuItem(
          onTap: onDashboardPressed,
          child: const Row(
            children: [
              Icon(
                Icons.dashboard_outlined,
                size: 20,
                color: Colors.white70,
              ),
              SizedBox(width: 8),
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),

        // Payment Settings
        PopupMenuItem(
          onTap: () {
            Navigator.pushNamed(context, '/payment-settings');
          },
          child: const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: Colors.white70,
              ),
              SizedBox(width: 8),
              Text(
                'Payment Settings',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),

        // Logout Option
        PopupMenuItem(
          onTap: onLogoutPressed,
          child: const Row(
            children: [
              Icon(
                Icons.logout,
                size: 20,
                color: Colors.white70,
              ),
              SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}