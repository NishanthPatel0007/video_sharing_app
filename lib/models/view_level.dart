class ViewLevel {
  final int level;
  final int requiredViews;

  const ViewLevel(this.level, this.requiredViews);

  static const List<ViewLevel> levels = [
    ViewLevel(0, 0),     // Starting level
    ViewLevel(1, 2),     // First milestone
    ViewLevel(2, 5),     // Second milestone
    ViewLevel(3, 20),    // Third milestone
    ViewLevel(4, 50),    // Fourth milestone
    ViewLevel(5, 100),   // Fifth milestone
    ViewLevel(6, 200),   // Sixth milestone
    ViewLevel(7, 500),   // Final milestone
  ];

  static ViewLevel getCurrentLevel(int views) {
    for (var i = levels.length - 1; i >= 0; i--) {
      if (views >= levels[i].requiredViews) {
        return levels[i];
      }
    }
    return levels.first;
  }

  static ViewLevel? getNextLevel(int views) {
    for (var level in levels) {
      if (views < level.requiredViews) {
        return level;
      }
    }
    return null;
  }

  static int getProgress(int views) {
    final currentLevel = getCurrentLevel(views);
    final nextLevel = getNextLevel(views);
    
    if (nextLevel == null) return 100;
    
    final levelViews = views - currentLevel.requiredViews;
    final viewsNeeded = nextLevel.requiredViews - currentLevel.requiredViews;
    
    return ((levelViews / viewsNeeded) * 100).clamp(0, 100).toInt();
  }

  static int viewsToNextLevel(int currentViews) {
    final nextLevel = getNextLevel(currentViews);
    if (nextLevel == null) return 0;
    return nextLevel.requiredViews - currentViews;
  }

  static bool isLevelCompleted(int level, int views) {
    if (level >= levels.length) return false;
    return views >= levels[level].requiredViews;
  }

  static bool isMaxLevel(int views) {
    return views >= levels.last.requiredViews;
  }
}