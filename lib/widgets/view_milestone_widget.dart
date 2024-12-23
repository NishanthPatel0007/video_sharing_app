import 'package:flutter/material.dart';

import '../constants/theme_constants.dart';
import '../models/view_level.dart';
import 'milestone_circle.dart';

class ViewMilestoneWidget extends StatelessWidget {
  final int views;
  final ScrollController _scrollController = ScrollController();
  
  ViewMilestoneWidget({
    Key? key,
    required this.views,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentLevel = ViewLevel.getCurrentLevel(views);
    final nextLevel = ViewLevel.getNextLevel(views);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ThemeConstants.deepPurple,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Section
          Text(
            'View\'s Milestone',
            style: TextStyle(
              color: ThemeConstants.textWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Next Milestone Info
          if (nextLevel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Next Milestone: ${nextLevel.requiredViews - views} more views needed',
              style: TextStyle(
                color: ThemeConstants.textGrey,
                fontSize: 14,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Milestone Circles with Scroll
          SizedBox(
            height: 60,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.purple,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.purple,
                  ],
                  stops: const [0.0, 0.05, 0.95, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstOut,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(ViewLevel.levels.length * 2 - 1, (index) {
                      // For progress lines (odd indices)
                      if (index.isOdd) {
                        final levelIndex = index ~/ 2;
                        final isCompleted = views >= ViewLevel.levels[levelIndex + 1].requiredViews;
                        final isActive = !isCompleted && 
                            views >= ViewLevel.levels[levelIndex].requiredViews &&
                            views < ViewLevel.levels[levelIndex + 1].requiredViews;
                        
                        return Container(
                          width: 40,
                          height: 2,
                          color: isCompleted || isActive
                              ? ThemeConstants.brightPurple
                              : ThemeConstants.progressInactive,
                        );
                      }
                      
                      // For milestone circles (even indices)
                      final levelIndex = index ~/ 2;
                      final level = ViewLevel.levels[levelIndex];
                      final isCompleted = views >= level.requiredViews;
                      final isActive = level.level == currentLevel.level;
                      
                      return Tooltip(
                        message: '${level.requiredViews} views required',
                        child: MilestoneCircle(
                          viewCount: level.requiredViews,
                          isActive: isActive,
                          isCompleted: isCompleted,
                          size: 45,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}