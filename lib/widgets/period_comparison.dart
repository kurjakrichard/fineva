import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../utils/utils.dart';

/// How [current] compares with the same figure of the period before
/// ([previous]): the change in percent with an arrow, and the value then.
/// Green when it changed the good way ([higherIsBetter]: income, the
/// difference; not for expenses), red the other way.
class PeriodComparison extends StatelessWidget {
  const PeriodComparison({
    super.key,
    required this.current,
    required this.previous,
    required this.currency,
    this.higherIsBetter = true,
  });

  final int current;
  final int previous;
  final Currency currency;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final then = l10n.previousPeriodValue(currency.format(previous, locale));
    // Nothing to compare in percent with 0.
    if (previous == 0 || current == previous) {
      return Text(then, style: textTheme.bodySmall?.copyWith(color: muted));
    }
    final up = current > previous;
    final good = up == higherIsBetter;
    final color = good ? incomeColor : expenseColor;
    final change = ((current - previous) / previous.abs()).abs();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: color,
        ),
        Text(
          NumberFormat.percentPattern(locale).format(change),
          style: textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Text(
            ' · $then',
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}
