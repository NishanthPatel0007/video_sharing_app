// lib/models/view_level.dart
class ViewLevel {
  final int level;
  final int requiredViews;
  final double rewardAmount;
  final String displayText;
  final bool canClaim;

  const ViewLevel(
    this.level, 
    this.requiredViews, 
    this.rewardAmount, 
    this.displayText, 
    {this.canClaim = false}
  );

  static const List<ViewLevel> levels = [
    ViewLevel(0, 0, 0, '0 Views'),             // Starting level
    ViewLevel(1, 1000, 40, '1K Views'),        // ₹40
    ViewLevel(2, 5000, 200, '5K Views'),       // ₹200
    ViewLevel(3, 10000, 400, '10K Views'),     // ₹400
    ViewLevel(4, 25000, 1000, '25K Views'),    // ₹1,000
    ViewLevel(5, 50000, 2000, '50K Views'),    // ₹2,000
    ViewLevel(6, 100000, 4000, '100K Views'),  // ₹4,000
    ViewLevel(7, 500000, 20000, '500K Views'), // ₹20,000
    ViewLevel(8, 1000000, 40000, '1M Views'),  // ₹40,000
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

  static String formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  static int getProgress(int views) {
    final currentLevel = getCurrentLevel(views);
    final nextLevel = getNextLevel(views);
    
    if (nextLevel == null) return 100;
    
    final levelViews = views - currentLevel.requiredViews;
    final viewsNeeded = nextLevel.requiredViews - currentLevel.requiredViews;
    
    return ((levelViews / viewsNeeded) * 100).clamp(0, 100).toInt();
  }

  static double getTotalPotentialEarnings(int views) {
    double total = 0;
    for (var level in levels) {
      if (views >= level.requiredViews) {
        total += level.rewardAmount;
      }
    }
    return total;
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

  static String formatReward(double amount) {
    if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  static bool canClaimReward(int views, int lastClaimedLevel) {
    final currentLevel = getCurrentLevel(views);
    return currentLevel.level > lastClaimedLevel && currentLevel.level > 0;
  }
}