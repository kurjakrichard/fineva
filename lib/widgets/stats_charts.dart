import 'dart:math' show max, min, pow;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';

/// Gray of the entries without category, as in EntryTile.
const int _noCategoryColor = 0xFF9E9E9E;

/// [amount] (in the smallest unit) in whole units of [currency], for the
/// charts' axes.
double _units(int amount, Currency currency) =>
    amount / pow(10, currency.decimals);

/// Short axis labels: "120 E", "1,2 M".
String _compact(double value, String locale) =>
    NumberFormat.compact(locale: locale).format(value);

/// Axis label text: small, in the muted text color.
TextStyle? _axisStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

FlGridData _grid(BuildContext context) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant,
    strokeWidth: 1,
  ),
);

/// Values on the left axis.
AxisTitles _leftTitles(BuildContext context) => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 48,
    getTitlesWidget: (value, meta) {
      // fl_chart labels the ends too; off the grid they overlap its labels.
      final onGrid =
          (value / meta.appliedInterval).roundToDouble() ==
          value / meta.appliedInterval;
      if (!onGrid) return const SizedBox.shrink();
      return SideTitleWidget(
        meta: meta,
        child: Text(
          _compact(value, context.localeName),
          style: _axisStyle(context),
        ),
      );
    },
  ),
);

const AxisTitles _noTitles = AxisTitles();

/// A figure with its label: income, expenses, net, savings rate.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.footer,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Below the value: how it compares with the period before.
  final Widget? footer;

  /// Marks which figure it is; the value itself stays in the text color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final icon = this.icon;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 6),
                ],
                Expanded(child: Text(label, style: textTheme.bodyMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (footer case final footer?) ...[
              const SizedBox(height: 4),
              footer,
            ],
          ],
        ),
      ),
    );
  }
}

/// How the entries of one type split between the categories: a thin
/// segmented bar of the largest ones, then every category with its amount,
/// share and a bar against the largest.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({
    super.key,
    required this.totals,
    required this.currency,
  });

  /// The largest first.
  final List<CategoryTotal> totals;
  final Currency currency;

  /// Segments of the bar; the rest is one gray "other" segment.
  static const int segments = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sum = totals.fold(0, (sum, t) => sum + t.amount);
    final largest = totals.first.amount;
    final rest = totals
        .skip(segments)
        .fold(0, (sum, total) => sum + total.amount);
    final percent = NumberFormat.percentPattern(context.localeName);

    Color color(CategoryTotal total) =>
        Color(total.category?.color ?? _noCategoryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The split at a glance; the rows below name the parts.
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(
              spacing: 2,
              children: [
                for (final total in totals.take(segments))
                  if (total.amount * 1000 ~/ sum > 0)
                    Expanded(
                      flex: total.amount * 1000 ~/ sum,
                      child: Container(color: color(total)),
                    ),
                if (rest * 1000 ~/ sum > 0)
                  Expanded(
                    flex: rest * 1000 ~/ sum,
                    child: Container(color: scheme.outlineVariant),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final total in totals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color(total),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        total.category == null
                            ? l10n.noCategory
                            : l10n.categoryName(total.category!),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      currency.format(total.amount, context.localeName),
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        percent.format(total.amount / sum),
                        textAlign: TextAlign.end,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Ranked bars: one hue, on one baseline.
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 56),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total.amount / largest,
                      minHeight: 6,
                      color: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The balance of [points] as a line, with the day and amount of the
/// touched point.
class BalanceLineChart extends StatelessWidget {
  const BalanceLineChart({
    super.key,
    required this.points,
    required this.currency,
    required this.monthly,
  });

  final List<BalancePoint> points;
  final Currency currency;

  /// A point a month (at its end) instead of a day.
  final bool monthly;

  // A label under the point [index], or null.
  String? _label(int index, String locale) {
    final date = points[index].date;
    final count = points.length;
    if (monthly) {
      // Every January, or every quarter if it's short.
      if (count <= 24) {
        return (date.month - 1) % 3 == 0
            ? DateFormat.yMMM(locale).format(date)
            : null;
      }
      return date.month == 1 ? '${date.year}' : null;
    }
    final first = points.first.date;
    final oneMonth =
        first.year == points.last.date.year &&
        first.month == points.last.date.month;
    // A week: every day; up to a month: every 7th day; up to a quarter: the
    // months; longer: the quarters.
    if (count <= 7) return '${date.day}.';
    if (count <= 31) {
      if (oneMonth) {
        return const {1, 8, 15, 22, 29}.contains(date.day)
            ? '${date.day}.'
            : null;
      }
      return index % 7 == 0 ? DateFormat.MMMd(locale).format(date) : null;
    }
    if (count <= 100) {
      return date.day == 1 ? DateFormat.MMM(locale).format(date) : null;
    }
    return date.day == 1 && (date.month - 1) % 3 == 0
        ? DateFormat.MMM(locale).format(date)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = context.localeName;
    final values = [for (final p in points) _units(p.balance, currency)];
    var low = values.reduce(min);
    var high = values.reduce(max);
    // Room above and below the line; the 0 line if it's near.
    final margin = high == low ? max(high.abs(), 1) * 0.1 : (high - low) * 0.1;
    low = low >= 0 && low - margin < 0 ? 0 : low - margin;
    high += margin;
    final dateFormat = monthly
        ? DateFormat.yMMM(locale)
        : DateFormat.yMMMd(locale);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(points.length - 1, 1).toDouble(),
        minY: low,
        maxY: high,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: _noTitles,
          rightTitles: _noTitles,
          leftTitles: _leftTitles(context),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                final label = value == index && index < points.length
                    ? _label(index, locale)
                    : null;
                if (label == null) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(label, style: _axisStyle(context)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: scheme.outline, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 5,
                        color: scheme.primary,
                        strokeWidth: 2,
                        strokeColor: scheme.surface,
                      ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${dateFormat.format(points[spot.spotIndex].date)}\n',
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                  children: [
                    TextSpan(
                      text: currency.format(
                        points[spot.spotIndex].balance,
                        locale,
                      ),
                      style: TextStyle(
                        color: scheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            color: scheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Income and expense bars side by side for each bucket, with the bucket's
/// name and the amount of the touched bar.
class CashFlowBarChart extends StatelessWidget {
  const CashFlowBarChart({
    super.key,
    required this.buckets,
    required this.currency,
    required this.label,
  });

  final List<CashFlowBucket> buckets;
  final Currency currency;

  /// Name of a bucket under its bars.
  final String Function(CashFlowBucket bucket) label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = context.localeName;
    final top = buckets.fold(0, (top, b) => max(top, max(b.income, b.expense)));
    final maxY = top == 0 ? 1.0 : _units(top, currency) * 1.1;
    const rounded = BorderRadius.vertical(top: Radius.circular(4));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two bars and a gap in each group's share of the width.
        final groupWidth = (constraints.maxWidth - 48) / buckets.length;
        final rodWidth = (groupWidth / 3).clamp(4.0, 16.0);
        // Only every [labelStep]th label if they don't fit side by side.
        final labelStep = (36 / groupWidth).ceil().clamp(1, buckets.length);
        return BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(context),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: _noTitles,
              rightTitles: _noTitles,
              leftTitles: _leftTitles(context),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index % labelStep != 0) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        label(buckets[index]),
                        style: _axisStyle(context),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final bucket = buckets[groupIndex];
                  final income = rodIndex == 0;
                  return BarTooltipItem(
                    '${label(bucket)}\n',
                    TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                    children: [
                      TextSpan(
                        text:
                            '${income ? l10n.income : l10n.expense}: '
                            '${currency.format(income ? bucket.income : bucket.expense, locale)}',
                        style: TextStyle(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < buckets.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    BarChartRodData(
                      toY: _units(buckets[i].income, currency),
                      color: incomeColor,
                      width: rodWidth,
                      borderRadius: rounded,
                    ),
                    BarChartRodData(
                      toY: _units(buckets[i].expense, currency),
                      color: expenseColor,
                      width: rodWidth,
                      borderRadius: rounded,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A colored square and the name of a series.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final (color, name) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(name, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
