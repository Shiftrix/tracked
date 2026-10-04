import 'package:flutter/material.dart';

/// A GitHub-contribution-style heatmap strip for a range of weeks.
/// 7 rows (Mon-Sun) × however many weeks fit in the range.
/// Cells are small rounded squares with a tiny inner gap — mosaic style.
///
/// Display-only. No tap handling.
class GithubHeatmapStrip extends StatelessWidget {
  /// First day of the range (inclusive).
  final DateTime rangeStart;

  /// Last day of the range (inclusive).
  final DateTime rangeEnd;

  /// Per-day totals. Keys are local midnight of each day.
  final Map<DateTime, Duration> dailyTotals;

  /// Colour for non-empty cells.
  final Color color;

  const GithubHeatmapStrip({
    super.key,
    required this.rangeStart,
    required this.rangeEnd,
    required this.dailyTotals,
    required this.color,
  });

  int _bucketFor(Duration d) {
    final minutes = d.inMinutes;
    if (minutes <= 0) return 0;
    if (minutes < 30) return 1;
    if (minutes < 60) return 2;
    if (minutes < 120) return 3;
    if (minutes < 180) return 4;
    return 5;
  }

  double _opacityForBucket(int bucket) {
    switch (bucket) {
      case 0:
        return 0.0;
      case 1:
        return 0.25;
      case 2:
        return 0.45;
      case 3:
        return 0.65;
      case 4:
        return 0.82;
      case 5:
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emptyColor = scheme.surfaceContainerHighest.withValues(alpha: 0.5);

    // Weekday alignment: which row does rangeStart fall on?
    // Monday = 1 in Dart's DateTime.weekday, so subtract 1.
    final leadingBlanks = rangeStart.weekday - 1;
    final dayCount = rangeEnd.difference(rangeStart).inDays + 1;
    final totalCells = leadingBlanks + dayCount;
    final weeks = (totalCells / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / weeks;

        return SizedBox(
          height: cellSize * 7,
          child: Row(
            children: [
              for (int w = 0; w < weeks; w++)
                Column(
                  children: [
                    for (int d = 0; d < 7; d++)
                      _buildCell(
                        w * 7 + d,
                        leadingBlanks,
                        dayCount,
                        cellSize,
                        emptyColor,
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCell(
    int cellIndex,
    int leadingBlanks,
    int dayCount,
    double cellSize,
    Color emptyColor,
  ) {
    // Padding inside the fixed cellSize box: cell occupies exactly
    // cellSize × cellSize, visual square is cellSize * 0.84.
    final innerPad = cellSize * 0.08;

    // Cells before the range start or after the range end are blanks.
    if (cellIndex < leadingBlanks || cellIndex >= leadingBlanks + dayCount) {
      return SizedBox(width: cellSize, height: cellSize);
    }

    final dayIndex = cellIndex - leadingBlanks;
    final date = rangeStart.add(Duration(days: dayIndex));
    final total = dailyTotals[date] ?? Duration.zero;
    final bucket = _bucketFor(total);

    final Color cellColor = bucket == 0
        ? emptyColor
        : color.withValues(alpha: _opacityForBucket(bucket));

    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: Padding(
        padding: EdgeInsets.all(innerPad),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(cellSize * 0.2),
          ),
        ),
      ),
    );
  }
}
