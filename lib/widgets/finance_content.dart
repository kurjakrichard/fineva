import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/providers.dart';
import 'account_dialog.dart';

/// A page's content from [builder] once the data is loaded and there is an
/// account (for an invoices only user, `Profile.invoicesOnly`, without
/// one). Before that a progress indicator, after a failed load the error,
/// without accounts a button to add the first one.
class FinanceContent extends StatelessWidget {
  const FinanceContent({super.key, required this.state, required this.builder});

  final FinanceState state;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = state.error;
    if (!state.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _Message(text: l10n.loadError(error));
    }
    if (state.accounts.isEmpty && !(state.profile?.invoicesOnly ?? false)) {
      return _Message(
        text: l10n.noAccounts,
        action: FilledButton.icon(
          onPressed: () => showAccountDialog(context),
          icon: const Icon(Icons.add),
          label: Text(l10n.addAccount),
        ),
      );
    }
    return builder(context);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
