import 'package:flutter/material.dart';

/// A month heatmap. Days are shaded based on hours logged that day.
class MonthHeatmap extends StatelessWidget {
  /// The month to display (any day inside it is fine; we normalize).
  final DateTime month;

  /// Per-day totals. Keys should be local midnight of each day.
  final Map<DateTime, Duration> dailyTotals;

  final Color? overrideColor;

  const MonthHeatmap({
    super.key,
    required this.month,
    required this.dailyTotals,
    this.overrideColor,
  });

  /// Fixed thresholds — see our design discussion.
  /// Returns 0..5: 0 = nothing, 5 = 3h+.
  int _bucketFor(Duration d) {
    final minutes = d.inMinutes;
    if (minutes <= 0) return 0;
    if (minutes < 30) return 1;
    if (minutes < 60) return 2;
    if (minutes < 120) return 3;
    if (minutes < 180) return 4;
    return 5;
  }

  /// Public lookup so the legend can render matching colors.
  static Color colorForBucket(
    int bucket,
    ColorScheme scheme, {
    Color? overrideColor,
  }) {
    final base = overrideColor ?? scheme.primary;
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
    final firstOfMonth = DateTime(month.year, month.month, 1);
    // Days in month: day 0 of next month = last day of this month.
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Weekday of the 1st, where Monday = 1 ... Sunday = 7.
    final leadingBlanks = firstOfMonth.weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row: Mon..Sun
        Row(
          children: const [
            _DayLabel('M'),
            _DayLabel('T'),
            _DayLabel('W'),
            _DayLabel('T'),
            _DayLabel('F'),
            _DayLabel('S'),
            _DayLabel('S'),
          ],
        ),
        const SizedBox(height: 4),
        // Grid of cells
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leadingBlanks + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index < leadingBlanks) {
              return const SizedBox.shrink();
            }
            final dayNumber = index - leadingBlanks + 1;
            final date = DateTime(month.year, month.month, dayNumber);
            final total = dailyTotals[date] ?? Duration.zero;
            final bucket = _bucketFor(total);
            final color = MonthHeatmap.colorForBucket(
              bucket,
              scheme,
              overrideColor: overrideColor,
            );

            return GestureDetector(
              onTap: () {
                final String text;
                if (total.inSeconds == 0) {
                  text = 'No time on $dayNumber/${month.month}';
                } else if (total.inMinutes == 0) {
                  text = '$dayNumber/${month.month}: ${total.inSeconds}s';
                } else {
                  text =
                      '$dayNumber/${month.month}: ${total.inHours}h '
                      '${total.inMinutes.remainder(60)}m '
                      '${total.inSeconds.remainder(60)}s';
                }
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(text),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: bucket >= 3
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 6),
            for (int b = 0; b <= 5; b++) ...[
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: MonthHeatmap.colorForBucket(
                    b,
                    scheme,
                    overrideColor: overrideColor,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              'More',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  final String text;
  const _DayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
