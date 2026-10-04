import 'package:flutter/material.dart';

import '../database.dart';
import '../theme/activity_appearance.dart';
import '../widgets/heatmap.dart';

/// Shows a stack of monthly heatmaps for one year, with arrows to
/// change year. Filtered to a single activity, or all if activity is null.
class YearViewScreen extends StatefulWidget {
  final Activity? activity;
  final int? overrideColorIndex;

  const YearViewScreen({super.key, this.activity, this.overrideColorIndex});

  @override
  State<YearViewScreen> createState() => _YearViewScreenState();
}

class _YearViewScreenState extends State<YearViewScreen> {
  late int _year;
  Map<DateTime, Duration> _dailyTotals = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final yearStart = DateTime(_year, 1, 1);
    final yearEnd = DateTime(_year + 1, 1, 1);
    final daily = await AppDatabase.getDailyTotalsFor(
      widget.activity?.id,
      yearStart,
      yearEnd,
    );

    if (!mounted) return;
    setState(() {
      _dailyTotals = daily;
      _loading = false;
    });
  }

  void _changeYear(int delta) {
    setState(() => _year += delta);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.activity?.name ?? 'All activity';
    final colorIndex =
        widget.activity?.colorIndex ?? (widget.overrideColorIndex ?? 0);
    final color = ActivityAppearance.color(colorIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color.withValues(alpha: 0.15),
      ),
      body: Column(
        children: [
          // Year selector bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeYear(-1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$_year',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeYear(1),
                ),
              ],
            ),
          ),

          // Month stack
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: 12,
                    itemBuilder: (context, i) {
                      final monthIndex = i + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _monthName(monthIndex),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            MonthHeatmap(
                              month: DateTime(_year, monthIndex, 1),
                              dailyTotals: _dailyTotals,
                              overrideColor: color,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
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
    return names[m - 1];
  }
}
