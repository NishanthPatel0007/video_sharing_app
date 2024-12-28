// lib/widgets/view_milestone_widget.dart
import 'package:flutter/material.dart';

import '../models/view_level.dart';

class ViewMilestoneWidget extends StatelessWidget {
  final int views;
  final int lastClaimedLevel;
  final bool isProcessingClaim;
  final Function(int level, double amount) onClaimPressed;
  final List<String> claimedMilestones;

  const ViewMilestoneWidget({
    Key? key,
    required this.views,
    required this.lastClaimedLevel,
    required this.onClaimPressed,
    this.isProcessingClaim = false,
    this.claimedMilestones = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            width: ViewLevel.levels.length * 160.0, // Fixed width for each milestone
            child: Stack(
              children: [
                // Progress Line
                Positioned(
                  left: 30,
                  right: 30,
                  top: 30,
                  child: Container(
                    height: 2,
                    color: const Color(0xFF2D2940),
                  ),
                ),
                // Milestone Circles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _buildMilestones(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMilestones() {
    final currentLevel = ViewLevel.getCurrentLevel(views);
    
    return ViewLevel.levels.map((level) {
      final isCompleted = views >= level.requiredViews;
      final isCurrent = level == currentLevel;
      final isClaimed = claimedMilestones.contains(level.level.toString());
      
      return SizedBox(
        width: 140,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Milestone Circle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getCircleColor(level, currentLevel),
                border: Border.all(
                  color: isCompleted ? const Color(0xFF8257E5) : Colors.white24,
                  width: 2,
                ),
                boxShadow: isCompleted ? [
                  BoxShadow(
                    color: const Color(0xFF8257E5).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ] : null,
              ),
              child: Center(
                child: Text(
                  level.displayText,
                  style: TextStyle(
                    color: isCompleted ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Reward Amount
            if (level.rewardAmount > 0) ...[
              Text(
                ViewLevel.formatReward(level.rewardAmount),
                style: TextStyle(
                  color: isCompleted ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Claim Button or Status
              SizedBox(
                height: 32,
                child: _buildClaimButton(level, isClaimed, isCompleted, isCurrent),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildClaimButton(
    ViewLevel level,
    bool isClaimed,
    bool isCompleted,
    bool isCurrent,
  ) {
    if (isClaimed) {
      return const Text(
        'Claimed',
        style: TextStyle(
          color: Color(0xFF4CAF50),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (isProcessingClaim && isCurrent) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8257E5)),
        ),
      );
    }

    if (isCompleted && level.level > lastClaimedLevel) {
      return ElevatedButton(
        onPressed: isProcessingClaim 
            ? null 
            : () => onClaimPressed(level.level, level.rewardAmount),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8257E5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minimumSize: const Size(80, 28),
          textStyle: const TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: Text('Claim ${ViewLevel.formatReward(level.rewardAmount)}'),
      );
    }

    // Future milestone
    return Text(
      isCompleted ? 'Unlocked' : 'Locked',
      style: TextStyle(
        color: isCompleted ? Colors.white70 : Colors.white38,
        fontSize: 12,
      ),
    );
  }

  Color _getCircleColor(ViewLevel level, ViewLevel currentLevel) {
    if (level.level == currentLevel.level) {
      return const Color(0xFF2D2940);
    }
    if (views >= level.requiredViews) {
      return const Color(0xFF2A2141);
    }
    return const Color(0xFF1E1633);
  }
}

class MilestoneProgressLine extends StatelessWidget {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const MilestoneProgressLine({
    Key? key,
    required this.progress,
    this.activeColor = const Color(0xFF8257E5),
    this.inactiveColor = const Color(0xFF2D2940),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final activeWidth = width * progress.clamp(0.0, 1.0);

          return Stack(
            children: [
              Container(
                width: width,
                color: inactiveColor,
              ),
              Container(
                width: activeWidth,
                color: activeColor,
              ),
            ],
          );
        },
      ),
    );
  }
}

class MilestoneTooltip extends StatelessWidget {
  final String text;
  final Widget child;

  const MilestoneTooltip({
    Key? key,
    required this.text,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2940),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF8257E5),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}