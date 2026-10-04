/// XP and level math for Tracked.
///
/// Design decisions:
/// - 1 XP per minute is the baseline rate (before multipliers).
/// - Activity multipliers scale that (e.g. Editing ×1.5, Gaming ×0.8).
/// - Level curve is linear-quadratic: total XP for level N = 100 * N * (N+1) / 2
///   Level 1 = 100 XP
///   Level 2 = 300 XP
///   Level 3 = 600 XP
///   Level 4 = 1000 XP
///   Level N = 100 * N * (N+1) / 2
library;

class Xp {
  /// Total XP required to REACH a given level (from zero).
  /// E.g. xpForLevel(1) = 100, xpForLevel(2) = 300, xpForLevel(3) = 600.
  static int xpForLevel(int level) {
    if (level <= 0) return 0;
    return 100 * level * (level + 1) ~/ 2;
  }

  /// Current level from a total XP amount. Level 0 until you hit 100 XP.
  static int levelFromXp(int totalXp) {
    if (totalXp < 100) return 0;
    // Solve n^2 + n - totalXp/50 = 0 approximately, then adjust.
    int level = 0;
    while (xpForLevel(level + 1) <= totalXp) {
      level++;
    }
    return level;
  }

  /// XP earned within the current level (for the progress bar).
  static int xpIntoLevel(int totalXp) {
    final level = levelFromXp(totalXp);
    return totalXp - xpForLevel(level);
  }

  /// XP required to reach the NEXT level from current total.
  static int xpForNextLevel(int totalXp) {
    final level = levelFromXp(totalXp);
    return xpForLevel(level + 1) - xpForLevel(level);
  }

  /// Progress within the current level, 0.0 to 1.0. For the XP bar.
  static double progressInLevel(int totalXp) {
    final needed = xpForNextLevel(totalXp);
    if (needed <= 0) return 1.0;
    return (xpIntoLevel(totalXp) / needed).clamp(0.0, 1.0);
  }

  /// Compute XP earned from a session.
  /// [durationMs] is the raw session length in milliseconds.
  /// [multiplier] is the activity's multiplier (default 1.0).
  /// Returns an integer XP value, floored to whole XP.
  static int xpForSession(int durationMs, double multiplier) {
    final minutes = durationMs / 60000.0;
    return (minutes * multiplier).floor();
  }
}
