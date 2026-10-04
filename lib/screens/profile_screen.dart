import 'package:flutter/material.dart';

import '../profile_store.dart';
import '../theme/activity_appearance.dart';
import '../widgets/profile_edit_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = ProfileStore.defaultName;
  int _avatarColor = ProfileStore.defaultAvatarColor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileStore.load();
    if (!mounted) return;
    setState(() {
      _name = profile.name;
      _avatarColor = profile.avatarColor;
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

          // Placeholder for XP bar (Session 2B)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_awesome, size: 40, color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  'XP bar coming next',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
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
