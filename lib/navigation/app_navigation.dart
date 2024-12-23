// lib/navigation/app_navigation.dart
import 'package:flutter/material.dart';

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

    return Container(
      height: navHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Side - Logo and Brand
          InkWell(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/');
            },
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
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
                    'Video Sharing',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right Side - Navigation Items
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentUser != null) ...[
                // Dashboard Button
                if (!isSmallScreen)
                  TextButton.icon(
                    onPressed: onDashboardPressed,
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Dashboard'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
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
                    backgroundColor: Theme.of(context).primaryColor,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            radius: 16,
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
          const Icon(Icons.arrow_drop_down),
        ],
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: 8),
              Text(
                currentUser ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: onDashboardPressed,
          child: const Row(
            children: [
              Icon(Icons.dashboard_outlined, size: 20),
              SizedBox(width: 8),
              Text(
                'Dashboard',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: onLogoutPressed,
          child: const Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}