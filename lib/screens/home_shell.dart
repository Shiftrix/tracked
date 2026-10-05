import 'package:flutter/material.dart';

import 'activity_list.dart';
import 'activity_detail.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';
import '../database.dart';
import '../theme/activity_appearance.dart';

import 'dart:async';

/// Container with bottom navigation between Timers, Tasks, and You.
/// Shows a live "running" pill above the nav bar when a session is active.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _profileKey = GlobalKey<ProfileScreenState>();
  final _runningKey = GlobalKey<_RunningIndicatorState>();

  late final List<Widget> _screens = [
    const ActivityListScreen(),
    const TasksScreen(),
    ProfileScreen(key: _profileKey),
  ];

  void _onTabChanged(int newIndex) {
    setState(() => _index = newIndex);
    if (newIndex == 2) {
      _profileKey.currentState?.reload();
    }
    // Refresh the running pill in case it changed.
    _runningKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          // Floating pill, positioned just above the nav bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: _RunningIndicator(
              key: _runningKey,
              onTap: (activity) async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ActivityDetailScreen(activity: activity),
                  ),
                );
                _runningKey.currentState?.reload();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timers',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }
}

/// A small pill above the nav bar showing whatever activity is currently
/// running. Invisible when nothing is running.
/// A small pill above the nav bar showing whatever activity is currently
/// running. Invisible when nothing is running.
class _RunningIndicator extends StatefulWidget {
  final void Function(Activity activity) onTap;

  const _RunningIndicator({super.key, required this.onTap});

  @override
  State<_RunningIndicator> createState() => _RunningIndicatorState();
}

class _RunningIndicatorState extends State<_RunningIndicator> {
  Activity? _activity;
  DateTime? _startedAt;
  int? _sessionId;
  bool _loading = true;

  /// Ticks once a second while a session is running, so the elapsed
  /// time stays live without a full reload.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    reload();
    // Poll the DB every 2 seconds to catch state changes from other screens.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollForChanges();
      if (mounted) setState(() {}); // redraw elapsed time
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    final session = await AppDatabase.getRunningSession();
    Activity? activity;
    if (session != null) {
      final activities = await AppDatabase.getActivities();
      for (final a in activities) {
        if (a.id == session.activityId) {
          activity = a;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _sessionId = session?.id;
      _activity = activity;
      _startedAt = session?.startedAt;
      _loading = false;
    });
  }

  /// Lightweight DB check — only updates state if something changed.
  /// Runs every second from the ticker. Cheap enough since it's one query.
  Future<void> _pollForChanges() async {
    final session = await AppDatabase.getRunningSession();
    // Session id changed (or appeared/disappeared)?
    if (session?.id != _sessionId) {
      await reload();
    }
  }

  String _formatClock(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _activity == null || _startedAt == null) {
      return const SizedBox.shrink();
    }

    final color = ActivityAppearance.color(_activity!.colorIndex);
    final elapsed = DateTime.now().difference(_startedAt!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTap(_activity!),
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Color.lerp(color, Colors.black, 0.3)!,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ActivityAppearance.icon(_activity!.iconIndex),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _activity!.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatClock(elapsed),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
