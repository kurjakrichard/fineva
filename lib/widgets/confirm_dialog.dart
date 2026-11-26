import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Asks [message] with Cancel / [confirmText] (Delete by default). True if
/// the user confirmed.
Future<bool> showConfirmDialog(
  BuildContext context,
  String message, {
  String? confirmText,
}) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText ?? l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows [message] at the bottom of the screen.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
