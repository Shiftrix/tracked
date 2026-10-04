import 'package:flutter/material.dart';

import '../profile_store.dart';
import '../theme/activity_appearance.dart';
import '../widgets/profile_edit_dialog.dart';
import '../database.dart';
import '../xp.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  String _name = ProfileStore.defaultName;
  int _avatarColor = ProfileStore.defaultAvatarColor;
  int _totalXp = 0;
  bool _loading = true;

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
    if (!mounted) return;
    setState(() {
      _name = profile.name;
      _avatarColor = profile.avatarColor;
      _totalXp = xp;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    final result = await showDialog<ProfileEditResult>(
      context: context,
      builder: (_) => ProfileEditDialog(
        initialName: _name,
        initialAvatarColor: _avatarColor,
      ),
    );
    if (result == null) return;
    await ProfileStore.save(name: result.name, avatarColor: result.avatarColor);
    await _load();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit profile',
            onPressed: _editProfile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Avatar
          Center(
            child: GestureDetector(
              onTap: _editProfile,
              child: Container(
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
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Center(
            child: Text(
              _name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
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
        ],
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
