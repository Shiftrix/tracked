import 'package:flutter/material.dart';

import '../profile_store.dart';
import '../theme/activity_appearance.dart';
import '../widgets/profile_edit_dialog.dart';
import '../database.dart';
import '../xp.dart';
import '../widgets/heatmap.dart';
import 'year_view.dart';

import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  String _name = ProfileStore.defaultName;
  int _avatarColor = ProfileStore.defaultAvatarColor;
  int _totalXp = 0;
  Duration _totalTime = Duration.zero;
  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _doneToday = false;
  bool _loading = true;
  Map<DateTime, Duration> _yearlyTotals = {};
  String? _avatarImagePath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Called by HomeShell when the You tab becomes active.
  /// Refreshes XP and any other data that might have changed elsewhere.
  Future<void> reload() async {
    await _load();
  }

  Future<void> _load() async {
    final profile = await ProfileStore.load();
    final xp = await AppDatabase.totalXp();
    final totalTime = await AppDatabase.totalTimeAllActivities();
    final streak = await AppDatabase.currentStreak();
    final longest = await AppDatabase.longestStreak();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final monthly = await AppDatabase.getDailyTotalsFor(
      null,
      monthStart,
      monthEnd,
    );

    if (!mounted) return;
    setState(() {
      _name = profile.name;
      _avatarColor = profile.avatarColor;
      _avatarImagePath = profile.avatarImagePath;
      _totalXp = xp;
      _totalTime = totalTime;
      _currentStreak = streak.current;
      _doneToday = streak.doneToday;
      _longestStreak = longest;
      _yearlyTotals = monthly;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    final result = await showDialog<ProfileEditResult>(
      context: context,
      builder: (_) => ProfileEditDialog(
        initialName: _name,
        initialAvatarColor: _avatarColor,
        initialAvatarImagePath: _avatarImagePath,
      ),
    );
    if (result == null) return;

    // Handle photo changes first.
    if (result.removeAvatarImage) {
      await ProfileStore.clearAvatarImage();
    } else if (result.newAvatarSourcePath != null) {
      await ProfileStore.saveAvatarImage(result.newAvatarSourcePath!);
    }

    await ProfileStore.save(name: result.name, avatarColor: result.avatarColor);
    await _load();
  }

  Widget _initialAvatar(Color color) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _name.isEmpty ? '?' : _name[0].toUpperCase(),
        style: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ActivityAppearance.color(_avatarColor);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('You'),
        backgroundColor: color.withValues(alpha: 0.15),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit profile',
            onPressed: _editProfile,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.15), Colors.transparent],
            stops: const [0.0, 0.4],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                onTap: _editProfile,
                child: _avatarImagePath != null
                    ? ClipOval(
                        child: Image.file(
                          File(_avatarImagePath!),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _initialAvatar(color),
                        ),
                      )
                    : _initialAvatar(color),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            Center(
              child: Text(
                _name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap to edit',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 40),

            _XpBar(totalXp: _totalXp, fillColor: color),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '${Xp.xpIntoLevel(_totalXp)} / ${Xp.xpForNextLevel(_totalXp)} XP',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 32),

            // Total time card
            _InfoCard(
              icon: Icons.schedule,
              accent: color,
              title: 'Total time tracked',
              value: Xp.formatBigDuration(_totalTime),
            ),
            const SizedBox(height: 12),

            // Streak card
            _StreakCard(
              current: _currentStreak,
              longest: _longestStreak,
              doneToday: _doneToday,
              accent: color,
            ),
            const SizedBox(height: 32),

            // Year heatmap section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateTime.now().year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('All years'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            YearViewScreen(overrideColorIndex: _avatarColor),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            MonthHeatmap(
              month: DateTime.now(),
              dailyTotals: _yearlyTotals,
              overrideColor: color,
            ),
          ],
        ),
      ),
    );
  }
}

/// Minecraft-style XP bar: a level badge above a chunky progress bar.
class _XpBar extends StatelessWidget {
  final int totalXp;
  final Color fillColor;

  const _XpBar({required this.totalXp, required this.fillColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Treat <100 XP as Level 1 so new users see "Level 1" not "Level 0".
    final rawLevel = Xp.levelFromXp(totalXp);
    final displayLevel = rawLevel < 1 ? 1 : rawLevel;

    // For the fill: if we forced level 1, the progress is totalXp / 100.
    // Otherwise use the standard helpers.
    double progress;
    if (rawLevel < 1) {
      progress = (totalXp / 100).clamp(0.0, 1.0);
    } else {
      progress = Xp.progressInLevel(totalXp);
    }

    return Column(
      children: [
        // Level badge above the bar — Minecraft style.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: fillColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Text(
            'Level $displayLevel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: fillColor,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // The bar itself.
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 24,
            child: Stack(
              children: [
                // Background track
                Container(color: scheme.surfaceContainerHighest),
                // Fill
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: fillColor,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [fillColor, fillColor.withValues(alpha: 0.75)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple info card with icon, title, and a big value.
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak card with Duolingo-style flame.
class _StreakCard extends StatelessWidget {
  final int current;
  final int longest;
  final bool doneToday;
  final Color accent;

  const _StreakCard({
    required this.current,
    required this.longest,
    required this.doneToday,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Lit flame when done today, grey otherwise.
    final flameColor = doneToday ? Colors.orange : scheme.onSurfaceVariant;
    final flameBgColor = doneToday
        ? Colors.orange.withValues(alpha: 0.15)
        : scheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: flameBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.local_fire_department,
              color: flameColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Streak',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  current == 1 ? '1 day' : '$current days',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: doneToday ? null : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (longest > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Best',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$longest',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
