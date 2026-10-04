import 'dart:async';

import 'package:flutter/material.dart';

import '../database.dart';
import '../widgets/heatmap.dart';
import 'year_view.dart';
import '../notifications.dart';
import '../theme/activity_appearance.dart';
import '../widgets/xp_toast.dart';

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

    final xpEarned = await AppDatabase.stopSession(_runningSessionId!);
    _ticker?.cancel();
    await _loadAll(); // refresh totals and session list
    AppNotifications.clear();

    if (!mounted) return;
    if (xpEarned > 0) {
      showXpToast(
        context,
        amount: xpEarned,
        color: ActivityAppearance.color(widget.activity.colorIndex),
      );
    }
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
        backgroundColor: ActivityAppearance.color(widget.activity.colorIndex)
            .withValues(alpha: 0.15),
        title: Row(
          children: [
            Hero(
              tag: 'activity-icon-${widget.activity.id}',
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ActivityAppearance.color(widget.activity.colorIndex)
                      .withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  ActivityAppearance.icon(widget.activity.iconIndex),
                  color: ActivityAppearance.color(widget.activity.colorIndex),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(widget.activity.name),
          ],
        ),
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
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ActivityAppearance.color(widget.activity.colorIndex)
                        .withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
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
                        color: running
                            ? Colors.green
                            : ActivityAppearance.color(
                                widget.activity.colorIndex,
                              ),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 32,
                ),
                child: Column(
                  children: [
                    Icon(
                      ActivityAppearance.icon(widget.activity.iconIndex),
                      size: 56,
                      color: ActivityAppearance.color(
                        widget.activity.colorIndex,
                      ).withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No sessions yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap Start to log your first one',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, i) {
                final s = _sessions[i];
                final dur = s.duration;
                final started = s.startedAt;
                final sessionColor = ActivityAppearance.color(
                  widget.activity.colorIndex,
                );
                final showXp = s.xpEarned > 0;

                return ListTile(
                  dense: true,
                  title: Text(
                    '${started.day}/${started.month} '
                    '${started.hour.toString().padLeft(2, '0')}:'
                    '${started.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dur == null ? 'running' : _formatSessionDuration(dur),
                      ),
                      if (showXp) ...[
                        const SizedBox(width: 10),
                        Text(
                          '(+${s.xpEarned} XP)',
                          style: TextStyle(
                            color: sessionColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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
