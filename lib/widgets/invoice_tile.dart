import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../utils/utils.dart';

/// An invoice in a list: the partner (the number without one), the gross
/// amount, the number, date, VAT code and description, and whether it is
/// paid; [number] is its sorszám in the year. Tapping it opens it.
class InvoiceTile extends StatelessWidget {
  const InvoiceTile({super.key, required this.invoice, this.number});

  final Invoice invoice;

  /// Sorszám in the year's record; none if null.
  final int? number;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final partner = invoice.partnerName;
    return RecordTile(
      onTap: () =>
          context.pushNamed<Invoice>(Routes.invoice.name, extra: invoice),
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: number == null
            ? const Icon(Icons.request_quote_outlined, size: 20)
            : Text('$number', style: textTheme.labelMedium),
      ),
      title: partner.isEmpty ? invoice.number : partner,
      amount: invoice.currency.format(invoice.gross, locale),
      details: [
        if (partner.isNotEmpty) invoice.number,
        DateFormat.yMMMd(locale).format(invoice.fulfillmentDate),
        invoice.vatCode.nav ?? '${invoice.vatCode.rate}%',
        if (invoice.partnerLocation != PartnerLocation.domestic)
          l10n.partnerLocationName(invoice.partnerLocation),
        if (invoice.description.isNotEmpty) invoice.description,
      ].join(' · '),
      footer: Row(
        children: [
          Icon(
            invoice.openAmount == 0 ? Icons.check_circle : Icons.schedule,
            size: 14,
            color: invoice.openAmount == 0
                ? incomeColor
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              invoice.openAmount == 0
                  ? l10n.paid
                  : l10n.openAmount(
                      invoice.currency.format(invoice.openAmount, locale),
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of a record (an invoice, a revenue): [leading], [title] with
/// [amount] on its right, and under them across the whole width [details]
/// and [footer]. Narrow on a phone: nothing but the amount beside the text.
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.leading,
    required this.title,
    required this.amount,
    required this.details,
    required this.footer,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String amount;
  final String details;
  final Widget footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: leading,
    title: Row(
      children: [
        Expanded(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
    isThreeLine: true,
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        footer,
      ],
    ),
  );
}
