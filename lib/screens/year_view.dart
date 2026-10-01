import 'package:flutter/material.dart';

import '../database.dart';

/// A full year of mini-months. Each day is a small dot, colored by
/// how much time was logged on that day for this activity.
class YearViewScreen extends StatefulWidget {
  final Activity activity;
  final int year;

  const YearViewScreen({super.key, required this.activity, required this.year});

  @override
  State<YearViewScreen> createState() => _YearViewScreenState();
}

class _YearViewScreenState extends State<YearViewScreen> {
  Map<DateTime, Duration> _dailyTotals = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final yearStart = DateTime(widget.year, 1, 1);
    final yearEnd = DateTime(widget.year + 1, 1, 1);
    final daily = await AppDatabase.getDailyTotalsFor(
      widget.activity.id!,
      yearStart,
      yearEnd,
    );
    if (!mounted) return;
    setState(() {
      _dailyTotals = daily;
      _loading = false;
    });
  }

  /// Same fixed thresholds as the detail-screen heatmap.
  int _bucketFor(Duration d) {
    final minutes = d.inMinutes;
    if (minutes <= 0) return 0;
    if (minutes < 30) return 1;
    if (minutes < 60) return 2;
    if (minutes < 120) return 3;
    if (minutes < 180) return 4;
    return 5;
  }

  Color _colorForBucket(int bucket, ColorScheme scheme) {
    final base = scheme.primary;
    switch (bucket) {
      case 0:
        return scheme.surfaceContainerHighest.withValues(alpha: 0.4);
      case 1:
        return base.withValues(alpha: 0.25);
      case 2:
        return base.withValues(alpha: 0.45);
      case 3:
        return base.withValues(alpha: 0.65);
      case 4:
        return base.withValues(alpha: 0.82);
      case 5:
      default:
        return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.year}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 12,
              itemBuilder: (context, monthIndex) {
                return _MiniMonth(
                  year: widget.year,
                  month: monthIndex + 1,
                  dailyTotals: _dailyTotals,
                  colorForBucket: (b) => _colorForBucket(b, scheme),
                  bucketFor: _bucketFor,
                );
              },
            ),
    );
  }
}

class _MiniMonth extends StatelessWidget {
  final int year;
  final int month;
  final Map<DateTime, Duration> dailyTotals;
  final Color Function(int) colorForBucket;
  final int Function(Duration) bucketFor;

  const _MiniMonth({
    required this.year,
    required this.month,
    required this.dailyTotals,
    required this.colorForBucket,
    required this.bucketFor,
  });

  String get _name {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingBlanks + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - leadingBlanks + 1;
              final date = DateTime(year, month, dayNumber);
              final total = dailyTotals[date] ?? Duration.zero;
              final bucket = bucketFor(total);
              return Container(
                decoration: BoxDecoration(
                  color: colorForBucket(bucket),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
