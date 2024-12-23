// You can either add this to landing_page.dart or create a new file app_footer.dart

import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© ${DateTime.now().year} Video Sharing. All rights reserved.',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {},
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}