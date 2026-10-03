import 'package:flutter/material.dart';

import '../database.dart';

import 'activity_detail.dart';

import 'dart:async';

import '../widgets/activity_dialog.dart';

import '../notifications.dart';

import '../theme/activity_appearance.dart';

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
    final result = await showDialog<ActivityDialogResult>(
      context: context,
      builder: (_) => const ActivityDialog(title: 'New activity'),
    );
    if (result == null || result.name.isEmpty) return;
    await AppDatabase.insertActivity(
      result.name,
      colorIndex: result.colorIndex,
      iconIndex: result.iconIndex,
    );
    await _load();
  }

  Future<void> _editActivity(Activity activity) async {
    final result = await showDialog<ActivityDialogResult>(
      context: context,
      builder: (_) => ActivityDialog(
        initialName: activity.name,
        initialColorIndex: activity.colorIndex,
        initialIconIndex: activity.iconIndex,
        title: 'Edit activity',
      ),
    );
    if (result == null || result.name.isEmpty) return;
    await AppDatabase.updateActivity(activity.id!, result.name);
    await AppDatabase.updateActivityAppearance(
      activity.id!,
      colorIndex: result.colorIndex,
      iconIndex: result.iconIndex,
    );
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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemCount: _activities.length,
                itemBuilder: (context, i) {
                  final a = _activities[i];
                  final total = _totals[a.id] ?? Duration.zero;
                  final isRunning = _runningSession?.activityId == a.id;

                  Duration? elapsed;
                  if (isRunning && _runningSession?.startedAt != null) {
                    elapsed = DateTime.now().difference(
                      _runningSession!.startedAt,
                    );
                  }

                  final subtitle = isRunning
                      ? 'Running: ${_formatLive(elapsed!)}  •  '
                            'Total: ${_formatDuration(total)}'
                      : _formatDuration(total);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ActivityDetailScreen(activity: a),
                          ),
                        );
                        _load();
                      },
                      onLongPress: () => _showRowMenu(a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            // Colored circle placeholder. In the next step
                            // we'll replace this with a per-activity icon.
                            Hero(
                              tag: 'activity-icon-${a.id}',
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isRunning
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : ActivityAppearance.color(a.colorIndex)
                                            .withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  isRunning
                                      ? Icons.play_arrow
                                      : ActivityAppearance.icon(a.iconIndex),
                                  color: isRunning
                                      ? Colors.green
                                      : ActivityAppearance.color(a.colorIndex),
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    a.name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: isRunning ? Colors.green : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isRunning
                                          ? Colors.green.withValues(alpha: 0.8)
                                          : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
