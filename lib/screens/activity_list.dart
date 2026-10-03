import 'package:flutter/material.dart';

import '../database.dart';

import 'activity_detail.dart';

import 'dart:async';

import '../widgets/activity_dialog.dart';

import '../notifications.dart';

/// Home screen: shows every activity with total hours logged.
class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({super.key});

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  List<Activity> _activities = [];
  Map<int, Duration> _totals = {};
  bool _loading = true;
  Session? _runningSession;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _addActivity() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const ActivityNameDialog(title: 'New activity'),
    );
    if (name == null || name.isEmpty) return;
    await AppDatabase.insertActivity(name);
    await _load();
  }

  Future<void> _editActivity(Activity activity) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => ActivityNameDialog(
        initialName: activity.name,
        title: 'Rename activity',
      ),
    );
    if (name == null || name.isEmpty) return;
    await AppDatabase.updateActivity(activity.id!, name);
    await _load();
  }

  Future<void> _deleteActivity(Activity activity) async {
    // Count sessions first so we can show the impact.
    final sessions = await AppDatabase.getSessionsFor(activity.id!);
    final total = await AppDatabase.totalDurationFor(activity.id!);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${activity.name}"?'),
        content: Text(
          sessions.isEmpty
              ? 'This activity has no logged sessions.'
              : 'This will also delete ${sessions.length} '
                    '${sessions.length == 1 ? "session" : "sessions"} '
                    'totalling ${_formatDuration(total)}.\n\n'
                    'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Was this the activity with the active session?
    final running = await AppDatabase.getRunningSession();
    final wasRunning = running?.activityId == activity.id;

    await AppDatabase.deleteActivity(activity.id!);
    if (wasRunning) AppNotifications.clear();
    await _load();
  }

  /// Long-press menu (Edit / Delete).
  Future<void> _showRowMenu(Activity activity) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'edit') {
      await _editActivity(activity);
    } else if (choice == 'delete') {
      await _deleteActivity(activity);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final activities = await AppDatabase.getActivities();
    final totals = <int, Duration>{};
    for (final a in activities) {
      totals[a.id!] = await AppDatabase.totalDurationFor(a.id!);
    }
    final running = await AppDatabase.getRunningSession();

    if (!mounted) return;
    setState(() {
      _activities = activities;
      _totals = totals;
      _runningSession = running;
      _loading = false;
    });
    _manageTicker();
  }

  void _manageTicker() {
    _ticker?.cancel();
    if (_runningSession != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0 && m == 0) return '0h 0m';
    return '${h}h ${m}m';
  }

  String _formatLive(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New activity',
            onPressed: _addActivity,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _activities.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = _activities[i];
                  final total = _totals[a.id] ?? Duration.zero;
                  final isRunning = _runningSession?.activityId == a.id;

                  // If this row is the running one, compute elapsed live.
                  Duration? elapsed;
                  if (isRunning && _runningSession?.startedAt != null) {
                    elapsed = DateTime.now().difference(
                      _runningSession!.startedAt,
                    );
                  }

                  return ListTile(
                    leading: isRunning
                        ? const Icon(
                            Icons.play_circle,
                            color: Colors.green,
                            size: 28,
                          )
                        : null,
                    title: Text(
                      a.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isRunning ? Colors.green : null,
                      ),
                    ),
                    subtitle: Text(
                      isRunning
                          ? 'Running: ${_formatLive(elapsed!)}  •  '
                                'Total: ${_formatDuration(total)}'
                          : _formatDuration(total),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ActivityDetailScreen(activity: a),
                        ),
                      );
                      _load();
                    },
                    onLongPress: () => _showRowMenu(a),
                  );
                },
              ),
            ),
    );
  }
}
