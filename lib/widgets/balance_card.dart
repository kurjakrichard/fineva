import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import 'amount_text.dart';
import 'missing_rates_note.dart';

/// The total balance in the user's main currency (the other currencies
/// converted at the rates of the day) and the balance of every account in
/// its own currency: now, or at the end of [date].
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.state, this.date});

  final FinanceState state;

  /// The day whose end the balances are of; null for now.
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final date = this.date;
    final balances = date == null ? state.balances : state.balancesAt(date);
    final day = date ?? currentDay();
    final main = state.mainCurrency;
    final total = state.totalInMain(balances, day);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date == null
                  ? l10n.balance
                  : l10n.balanceAt(
                      DateFormat.yMMMd(context.localeName).format(date),
                    ),
              style: textTheme.titleMedium,
            ),
            AmountText(total.total, main, style: textTheme.headlineMedium),
            MissingRatesNote(currencies: total.missing),
            const Divider(height: 24),
            for (final account in state.accounts)
              // A closed one only while it still had money.
              if (!account.isClosed || (balances[account.id] ?? 0) != 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(account.name)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AmountText(
                            balances[account.id] ?? 0,
                            account.currency,
                          ),
                          // Another currency: what it is worth in the main.
                          if (account.currency != main)
                            if (state.toMain(
                                  balances[account.id] ?? 0,
                                  account.currency,
                                  day,
                                )
                                case final value?)
                              Text(
                                '≈ ${main.format(value, context.localeName)}',
                                style: textTheme.bodySmall,
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
