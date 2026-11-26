import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../utils/utils.dart';

/// Formats the digits of a Hungarian tax number as they are typed:
/// 12345678-1-12. Other characters are dropped, the dashes come by
/// themselves, the cursor stays after the same digit.
class TaxNumberInputFormatter extends TextInputFormatter {
  const TaxNumberInputFormatter();

  static const int _digits = 11;

  static String format(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < _digits; i++) {
      if (i == 8 || i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);
    // The digits before the cursor, and where they are now.
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    var digitsBefore = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    var offset = 0;
    while (offset < text.length && digitsBefore > 0) {
      if (text[offset] != '-') digitsBefore--;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// A Hungarian tax number (adószám), typed as 12345678-1-12. Checked with
/// [parseTaxNumber] when given; [required] makes it mandatory with
/// [requiredText].
class TaxNumberField extends StatelessWidget {
  const TaxNumberField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.label,
    this.required = false,
    this.requiredText,
    this.helperText,
    this.textInputAction,
  });

  final String initialValue;

  /// Called with the stored form (12345678-1-12) once it is valid, with
  /// the text before.
  final ValueChanged<String> onChanged;
  final String? label;
  final bool required;
  final String? requiredText;
  final String? helperText;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      initialValue: TaxNumberInputFormatter.format(initialValue),
      decoration: InputDecoration(
        labelText: label ?? l10n.taxNumber,
        hintText: '12345678-1-12',
        helperText: helperText,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: const [TaxNumberInputFormatter()],
      textInputAction: textInputAction,
      autovalidateMode: AutovalidateMode.onUserInteractionIfError,
      validator: (text) {
        final value = text?.trim() ?? '';
        if (value.isEmpty) {
          return required ? requiredText ?? l10n.taxNumberInvalid : null;
        }
        return parseTaxNumber(value) == null ? l10n.taxNumberInvalid : null;
      },
      onChanged: (text) => onChanged(parseTaxNumber(text) ?? text.trim()),
    );
  }
}
