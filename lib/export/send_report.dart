import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'report.dart';
import 'report_pdf.dart';
import 'report_xlsx.dart';

enum ReportFormat {
  pdf('PDF', 'application/pdf'),
  xlsx(
    'XLSX',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  const ReportFormat(this.label, this.mimeType);

  final String label;
  final String mimeType;
}

/// The file of [report] in [format]; the PDF with the bundled font.
Future<Uint8List> reportBytes(
  Report report,
  ReportFormat format, [
  AssetBundle? bundle,
]) async {
  switch (format) {
    case ReportFormat.xlsx:
      return reportXlsx(report);
    case ReportFormat.pdf:
      final assets = bundle ?? rootBundle;
      Future<pw.Font> font(String name) async =>
          pw.Font.ttf(await assets.load('assets/fonts/Roboto-$name.ttf'));
      return reportPdf(
        report,
        regular: await font('Regular'),
        bold: await font('Bold'),
      );
  }
}

/// The share sheet can send a file: not on Linux (nor on the web).
bool get canShareFiles => !kIsWeb && !Platform.isLinux;

/// Sends [report] in [format] with the share sheet (e-mail, a message, a
/// drive); [save] instead saves it where the user picks. True when sent or
/// saved, false when cancelled; throws if it failed.
Future<bool> sendReport(
  Report report,
  ReportFormat format, {
  bool save = false,
}) async {
  final bytes = await reportBytes(report, format);
  final name = '${report.fileName}.${format.name}';
  if (save) {
    final path = await FilePicker.saveFile(
      dialogTitle: report.title,
      fileName: name,
      bytes: bytes,
    );
    return path != null;
  }
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: format.mimeType)],
      fileNameOverrides: [name],
      subject: report.title,
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}
