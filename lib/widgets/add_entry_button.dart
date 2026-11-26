import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/data_export.dart';
import '../l10n/l10n.dart';
import '../utils/utils.dart';

/// The + button that opens a new entry (on [account] if given). Only shown
/// when there is an account.
class AddEntryButton extends StatelessWidget {
  const AddEntryButton({super.key, this.account});

  final Account? account;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    tooltip: context.l10n.addEntry,
    onPressed: () => context.pushNamed(Routes.entry.name, extra: account),
    child: const Icon(Icons.add),
  );
}
