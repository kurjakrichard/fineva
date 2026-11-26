import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import 'responsive.dart';

/// [period] as the app shows it: "2026. november", "2026. 4. negyedév",
/// "nov. 16. – nov. 22.", "Teljes időszak". [short] for little room (an app
/// bar): "2026. nov.", "2026. Q4", "nov. 16.–nov. 22.".
String periodName(
  BuildContext context,
  DatePeriod period, {
  bool short = false,
}) {
  final l10n = context.l10n;
  final locale = context.localeName;
  final start = period.start;
  final last = period.last;
  if (start == null || last == null) return l10n.allTime;
  return switch (period.kind) {
    PeriodKind.month =>
      (short ? DateFormat.yMMM(locale) : DateFormat.yMMMM(locale)).format(
        start,
      ),
    PeriodKind.quarter =>
      short
          ? l10n.quarterOfYearShort((start.month + 2) ~/ 3, start.year)
          : l10n.quarterOfYear((start.month + 2) ~/ 3, start.year),
    PeriodKind.year => '${start.year}',
    PeriodKind.week ||
    PeriodKind.custom ||
    PeriodKind.all => _days(locale, start, last, short),
  };
}

/// "nov. 16. – nov. 22." in this year, with the years otherwise.
String _days(String locale, DateTime start, DateTime last, bool short) {
  final thisYear = currentDay().year;
  final format = start.year == thisYear && last.year == thisYear
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  if (start == last) return format.format(start);
  return '${format.format(start)}${short ? '–' : ' – '}'
      '${format.format(last)}';
}

/// Asks for a period: a week, month, quarter, year, all time, or days
/// chosen in a calendar. Null if cancelled; [current] if its kind is chosen
/// again. A new kind starts from today if [current] has it, otherwise from
/// [current]'s first day.
Future<DatePeriod?> showPeriodPicker(
  BuildContext context,
  DatePeriod current,
) async {
  final kind = await showDialog<PeriodKind>(
    context: context,
    builder: (context) => _PeriodKindDialog(selected: current.kind),
  );
  if (kind == null || !context.mounted) return null;
  if (kind == PeriodKind.all) return const DatePeriod.all();
  if (kind != PeriodKind.custom) {
    return kind == current.kind ? current : current.withKind(kind);
  }
  final today = currentDay();
  final start = current.start;
  final last = current.last;
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime(today.year + 5, 12, 31),
    initialDateRange: start == null || last == null
        ? null
        : DateTimeRange(start: start, end: last),
    currentDate: today,
  );
  return range == null ? null : DatePeriod.range(range.start, range.end);
}

/// The kinds of period as tiles, the [selected] one marked.
class _PeriodKindDialog extends StatelessWidget {
  const _PeriodKindDialog({required this.selected});

  final PeriodKind selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A badge with the days, or an icon.
    final kinds = [
      (PeriodKind.week, l10n.periodWeek, '7', null),
      (PeriodKind.month, l10n.periodMonth, '30', null),
      (PeriodKind.quarter, l10n.periodQuarter, '90', null),
      (PeriodKind.year, l10n.periodYear, '365', null),
      (PeriodKind.all, l10n.allTime, null, Icons.all_inclusive),
      (PeriodKind.custom, l10n.periodCustom, null, Icons.date_range),
    ];
    return AlertDialog(
      title: Text(l10n.choosePeriod),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            for (var row = 0; row < kinds.length; row += 2)
              Row(
                spacing: 8,
                children: [
                  for (final (kind, label, badge, icon) in kinds.sublist(
                    row,
                    row + 2,
                  ))
                    Expanded(
                      child: _KindTile(
                        label: label,
                        badge: badge,
                        icon: icon,
                        selected: kind == selected,
                        onTap: () => Navigator.pop(context, kind),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.label,
    required this.badge,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? badge;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    final badge = this.badge;
    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.secondaryContainer : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            spacing: 6,
            children: [
              SizedBox(
                height: 24,
                child: badge == null
                    ? Icon(icon, color: foreground)
                    : Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: foreground,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            child: Text(
                              badge,
                              style: textTheme.labelMedium?.copyWith(
                                color: selected
                                    ? scheme.secondaryContainer
                                    : scheme.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ‹ name ▾ ›: the period before and after, and the picker on the name.
/// It fills its width (a bottom bar); [dense] is as narrow as it can be,
/// with the short name, for the actions of an app bar. [color] is the
/// foreground on a colored bar (the app bar's).
class PeriodBar extends StatelessWidget {
  const PeriodBar({
    super.key,
    required this.period,
    required this.onChanged,
    this.color,
    this.dense = false,
  });

  final DatePeriod period;
  final ValueChanged<DatePeriod> onChanged;
  final Color? color;
  final bool dense;

  /// The widest the name is in an app bar of a phone; longer names (days
  /// of other years) are cut, the whole name is in the tooltip.
  static const double maxDenseNameWidth = 140;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = this.color;
    final iconStyle = IconButton.styleFrom(
      foregroundColor: color,
      disabledForegroundColor: color?.withValues(alpha: 0.38),
      // Narrow arrows: room for the title on a phone.
      padding: dense ? const EdgeInsets.symmetric(horizontal: 4) : null,
      minimumSize: dense ? const Size(32, 48) : null,
      tapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : null,
    );
    final name = periodName(context, period, short: dense);
    final button = Tooltip(
      message: '${l10n.choosePeriod}: ${periodName(context, period)}',
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: color,
          textStyle: Theme.of(context).textTheme.titleMedium,
          padding: dense ? const EdgeInsets.symmetric(horizontal: 2) : null,
        ),
        onPressed: () async {
          final chosen = await showPeriodPicker(context, period);
          if (chosen != null) onChanged(chosen);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
    return Row(
      mainAxisSize: dense ? MainAxisSize.min : MainAxisSize.max,
      children: [
        IconButton(
          tooltip: l10n.previousPeriod,
          style: iconStyle,
          onPressed: period.hasPrevious
              ? () => onChanged(period.previous)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        if (dense)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ScreenSize.of(context).isCompact
                  ? maxDenseNameWidth
                  : 2 * maxDenseNameWidth,
            ),
            child: button,
          )
        else
          Expanded(
            // As high as the button: in a bottom bar there is room for more.
            child: Center(heightFactor: 1, child: button),
          ),
        IconButton(
          tooltip: l10n.nextPeriod,
          style: iconStyle,
          onPressed: period.hasNext ? () => onChanged(period.next) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
