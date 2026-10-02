import 'package:flutter/material.dart';

import '../database.dart';

import 'activity_detail.dart';

import 'dart:async';

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
      appBar: AppBar(title: const Text('Life Tracker')),
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
                  );
                },
              ),
            ),
    );
  }
}
