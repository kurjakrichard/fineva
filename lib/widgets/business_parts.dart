import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import 'confirm_dialog.dart';
import 'max_width.dart';

/// A scrolling tab of the business page, at most [maxWidth] wide, with room
/// for the + button.
class BusinessList extends StatelessWidget {
  const BusinessList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MaxWidth(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: children,
    ),
  );
}

/// A label and an amount in a row; [strong] for a total.
class AmountRow extends StatelessWidget {
  const AmountRow(
    this.label,
    this.amount, {
    super.key,
    this.strong = false,
    this.hint,
  });

  final String label;
  final int amount;
  final bool strong;

  /// Small text under the label, e.g. the base of a tax.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hint = this.hint;
    final style = strong ? textTheme.titleSmall : textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (hint != null)
                  Text(
                    hint,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            Currency.huf.format(amount, context.localeName),
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A card with a title (and something beside it).
class BusinessCard extends StatelessWidget {
  const BusinessCard({
    super.key,
    required this.title,
    this.trailing,
    required this.children,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// How much of a yearly limit is used.
class LimitBar extends StatelessWidget {
  const LimitBar({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
  });

  final String label;
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final over = used > limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: textTheme.bodyMedium),
        Text(
          '${Currency.huf.format(used, locale)} / '
          '${Currency.huf.format(limit, locale)}',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: limit == 0 ? 0 : (used / limit).clamp(0, 1),
            minHeight: 8,
            color: over ? scheme.error : scheme.primary,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

/// A tax to transfer: name, NAV tax code, account (copyable), amount.
class TaxPaymentRow extends StatelessWidget {
  const TaxPaymentRow({super.key, required this.payment});

  final TaxPayment payment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final kind = payment.kind;
    final account = kind.account;
    final code = kind.code;
    final details = [
      if (code != null) l10n.taxCode(code),
      account ?? l10n.municipalityAccount,
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.taxKindName(kind), style: textTheme.bodyMedium),
              Text(details, style: textTheme.bodySmall),
            ],
          ),
        ),
        if (account != null)
          IconButton(
            tooltip: l10n.copyAccount,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: account));
              showMessage(context, l10n.copied(account));
            },
          ),
        Text(
          Currency.huf.format(payment.amount, context.localeName),
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// ‹ 2026 › for an app bar's actions: the year of the sole proprietor's
/// pages ([businessYearProvider], shared by them), not after this one.
class YearBar extends ConsumerWidget {
  const YearBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final year = ref.watch(businessYearProvider);
    final notifier = ref.read(businessYearProvider.notifier);
    // Narrow arrows: room for the title on a phone.
    const arrow = BoxConstraints.tightFor(width: 36, height: 48);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.previousYear,
            constraints: arrow,
            padding: EdgeInsets.zero,
            onPressed: () => notifier.set(year - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$year'),
          IconButton(
            tooltip: l10n.nextYear,
            constraints: arrow,
            padding: EdgeInsets.zero,
            onPressed: year < currentDay().year
                ? () => notifier.set(year + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
