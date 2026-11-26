import 'package:flutter/material.dart';

import '../export/export.dart';
import '../l10n/l10n.dart';
import 'confirm_dialog.dart';

/// Sends (or saves) a record ([report]: of what the page shows; null: none)
/// as a PDF or an XLSX ([sendReport]); only saves where the share sheet
/// can't send a file (Linux).
class SendReportButton extends StatelessWidget {
  const SendReportButton({super.key, required this.report});

  final Report? Function(AppLocalizations l10n) report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<(ReportFormat, bool)>(
      tooltip: l10n.sendReport,
      icon: const Icon(Icons.ios_share),
      onSelected: (choice) async {
        final (format, save) = choice;
        final report = this.report(l10n);
        if (report == null) return;
        try {
          final done = await sendReport(report, format, save: save);
          if (done && save && context.mounted) {
            showMessage(context, l10n.fileSaved);
          }
        } catch (e) {
          debugPrint('Sending the record failed: $e');
          if (context.mounted) showMessage(context, l10n.reportError);
        }
      },
      itemBuilder: (context) => [
        if (canShareFiles) ...[
          for (final format in ReportFormat.values)
            PopupMenuItem(
              value: (format, false),
              child: ListTile(
                leading: const Icon(Icons.send_outlined),
                title: Text(l10n.sendAs(format.label)),
              ),
            ),
          const PopupMenuDivider(),
        ],
        for (final format in ReportFormat.values)
          PopupMenuItem(
            value: (format, true),
            child: ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.saveAs(format.label)),
            ),
          ),
      ],
    );
  }
}
