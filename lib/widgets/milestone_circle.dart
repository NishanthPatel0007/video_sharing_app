import 'package:flutter/material.dart';

import '../constants/theme_constants.dart';

class MilestoneCircle extends StatelessWidget {
  final int viewCount;
  final bool isActive;
  final bool isCompleted;
  final double size;

  const MilestoneCircle({
    Key? key,
    required this.viewCount,
    this.isActive = false,
    this.isCompleted = false,
    this.size = 45,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive || isCompleted 
            ? ThemeConstants.brightPurple.withOpacity(0.2)
            : ThemeConstants.deepPurple,
        border: Border.all(
          color: isActive || isCompleted 
              ? ThemeConstants.brightPurple
              : ThemeConstants.progressInactive,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          viewCount.toString(),
          style: TextStyle(
            color: isActive || isCompleted
                ? ThemeConstants.textWhite
                : ThemeConstants.textGrey,
            fontSize: viewCount >= 100 ? 14 : 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}