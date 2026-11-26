import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/utils.dart';

/// A personal user's main currency.
class MainCurrencyField extends StatelessWidget {
  const MainCurrencyField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Currency value;
  final ValueChanged<Currency> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DropdownButtonFormField<Currency>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.mainCurrency,
        helperText: l10n.mainCurrencyText,
        helperMaxLines: 2,
      ),
      items: [
        for (final currency in Currency.values)
          DropdownMenuItem(
            value: currency,
            child: Text(
              l10n.currencyLabel(currency),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (currency) {
        if (currency != null && currency != value) onChanged(currency);
      },
    );
  }
}
