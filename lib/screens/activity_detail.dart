import 'dart:async';

import 'package:flutter/material.dart';

import '../database.dart';
import '../widgets/heatmap.dart';
import 'year_view.dart';
import '../notifications.dart';

/// Detail screen for one activity: live timer, Start/Stop, recent sessions.
class ActivityDetailScreen extends StatefulWidget {
  final Activity activity;
  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  /// The row id of the currently running session for THIS activity,
  /// or null if none is running.
  int? _runningSessionId;
  DateTime? _startedAt;

  /// Ticks once a second while a session is running, purely to redraw
  /// the elapsed time text. It doesn't affect the stored data.
  Timer? _ticker;

  List<Session> _sessions = [];
  Duration _total = Duration.zero;
  Duration _todayTotal = Duration.zero;
  Map<DateTime, Duration> _dailyTotals = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final running = await AppDatabase.getRunningSessionFor(widget.activity.id!);
    final sessions = await AppDatabase.getSessionsFor(widget.activity.id!);
    final total = await AppDatabase.totalDurationFor(widget.activity.id!);
    final today = await AppDatabase.totalForDay(
      widget.activity.id!,
      DateTime.now(),
    );

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final daily = await AppDatabase.getDailyTotalsFor(
      widget.activity.id!,
      monthStart,
      monthEnd,
    );

    if (!mounted) return;
    setState(() {
      _runningSessionId = running?.id;
      _startedAt = running?.startedAt;
      _sessions = sessions;
      _total = total;
      _todayTotal = today;
      _dailyTotals = daily;
    });
    _manageTicker();
  }

  void _manageTicker() {
    _ticker?.cancel();
    if (_runningSessionId != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {}); // just redraw
      });
    }
  }

  Future<void> _start() async {
    final id = await AppDatabase.startSession(widget.activity.id!);
    final now = DateTime.now();
    setState(() {
      _runningSessionId = id;
      _startedAt = now;
    });
    AppNotifications.showRunning(widget.activity.name);
    _manageTicker();
  }

  Future<void> _stop() async {
    if (_runningSessionId == null) return;
    await AppDatabase.stopSession(_runningSessionId!);
    _ticker?.cancel();
    await _loadAll(); // refresh totals and session list
    AppNotifications.clear();
  }

  /// Format a Duration as HH:MM:SS, for the live timer.
  String _formatClock(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Format a Duration as "1h 23m", for the totals.
  String _formatTotal(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  /// Format a duration for the session list: shows seconds if under a minute,
  /// otherwise "Xh Ym" like the totals do.
  String _formatSessionDuration(Duration d) {
    if (d.inMinutes < 1) {
      return '${d.inSeconds}s';
    }
    return _formatTotal(d);
  }

  @override
  Widget build(BuildContext context) {
    final running = _runningSessionId != null;
    final elapsed = running && _startedAt != null
        ? DateTime.now().difference(_startedAt!)
        : Duration.zero;
    // Add the currently-running elapsed time to both displayed totals,
    // so they tick live while a session is active.
    final liveToday = _todayTotal + elapsed;
    final liveTotal = _total + elapsed;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_month),
            tooltip: 'Year view',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => YearViewScreen(
                    activity: widget.activity,
                    year: DateTime.now().year,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Timer + today/total + Start/Stop button
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24 + 128),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    running ? _formatClock(elapsed) : '00:00:00',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: running ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Today: ${_formatTotal(liveToday)}  •  '
                    'Total: ${_formatTotal(liveTotal)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: running ? _stop : _start,
                    icon: Icon(running ? Icons.stop : Icons.play_arrow),
                    label: Text(running ? 'Stop' : 'Start'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Heatmap section
          const SliverToBoxAdapter(child: Divider(height: 1)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'This month',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MonthHeatmap(
                month: DateTime.now(),
                dailyTotals: _dailyTotals,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Recent sessions header
          const SliverToBoxAdapter(child: Divider(height: 1)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),

          // Sessions list — this is the sliver that actually grows.
          if (_sessions.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No completed sessions yet')),
              ),
            )
          else
            SliverList.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, i) {
                final s = _sessions[i];
                final dur = s.duration;
                final started = s.startedAt;
                return ListTile(
                  dense: true,
                  title: Text(
                    '${started.day}/${started.month} '
                    '${started.hour.toString().padLeft(2, '0')}:'
                    '${started.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: Text(
                    dur == null ? 'running' : _formatSessionDuration(dur),
                  ),
                );
              },
            ),

          // Bottom breathing room
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
