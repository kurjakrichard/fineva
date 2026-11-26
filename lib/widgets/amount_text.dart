import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/utils.dart';

/// [amount] of [currency]; green and with a + sign for income, red for an
/// expense when [signed].
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount,
    this.currency, {
    super.key,
    this.signed = false,
    this.style,
  });

  final int amount;
  final Currency currency;
  final bool signed;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = currency.format(amount, context.localeName);
    return Text(
      signed && amount > 0 ? '+$text' : text,
      style: (style ?? const TextStyle()).copyWith(
        color: signed ? (amount < 0 ? expenseColor : incomeColor) : null,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
