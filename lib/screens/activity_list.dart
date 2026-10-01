import 'package:flutter/material.dart';

import '../database.dart';

import 'activity_detail.dart';

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
    if (!mounted) return;
    setState(() {
      _activities = activities;
      _totals = totals;
      _loading = false;
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0 && m == 0) return '0h 0m';
    return '${h}h ${m}m';
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
                  return ListTile(
                    title: Text(
                      a.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(_formatDuration(total)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ActivityDetailScreen(activity: a),
                        ),
                      );
                      _load(); // refresh totals after returning
                    },
                  );
                },
              ),
            ),
    );
  }
}
