import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../utils/utils.dart';

/// "No exchange rate: USD" with a button to the rates page, under figures
/// that had to leave out the amounts of [currencies]. Nothing if empty.
class MissingRatesNote extends StatelessWidget {
  const MissingRatesNote({super.key, required this.currencies});

  final Set<Currency> currencies;

  @override
  Widget build(BuildContext context) {
    if (currencies.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final codes = [for (final c in currencies) c.code]..sort();
    return Row(
      children: [
        Icon(Icons.warning_amber, size: 18, color: scheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.missingRates(codes.join(', ')),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextButton(
          onPressed: () => context.push(Routes.rates.path),
          child: Text(l10n.exchangeRates),
        ),
      ],
    );
  }
}
