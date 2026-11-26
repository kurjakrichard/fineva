/// Hungarian tax identifiers, checked with their check digits.
library;

/// The tax identification number of a private person (adóazonosító jel) in
/// [text], as its 10 digits; null if it isn't a valid one. Spaces are
/// ignored.
///
/// It starts with 8, and its 10th digit is the sum of the first nine, each
/// multiplied by its position (1-9), modulo 11.
String? parseTaxId(String text) {
  final digits = text.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^8\d{9}$').hasMatch(digits)) return null;
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += _digit(digits, i) * (i + 1);
  }
  return sum % 11 == _digit(digits, 9) ? digits : null;
}

/// The tax number (adószám) in [text] as 12345678-1-12; null if it isn't a
/// valid one. The dashes may be left out, spaces are ignored.
///
/// The parts: the 8-digit base number (törzsszám, its last digit a check
/// digit), the VAT code (1-5) and the code of the tax office (2 digits).
String? parseTaxNumber(String text) {
  final match = RegExp(r'^(\d{8})-?([1-5])-?(\d{2})$')
      .firstMatch(text.replaceAll(RegExp(r'\s'), ''));
  if (match == null) return null;
  final base = match[1]!;
  if (!_isValidBase(base)) return null;
  return '$base-${match[2]}-${match[3]}';
}

/// The Hungarian EU VAT number (közösségi adószám) in [text] as HU12345678;
/// null if it isn't a valid one. The HU may be left out, spaces are
/// ignored, case doesn't matter.
///
/// It is HU and the base number (törzsszám) of the tax number, see
/// [taxNumberBase].
String? parseEuVatNumber(String text) {
  final match = RegExp(r'^(?:HU)?(\d{8})$')
      .firstMatch(text.replaceAll(RegExp(r'\s'), '').toUpperCase());
  if (match == null) return null;
  final base = match[1]!;
  return _isValidBase(base) ? 'HU$base' : null;
}

/// The base number (törzsszám, the first 8 digits) of a tax number as
/// [parseTaxNumber] returns it.
String taxNumberBase(String taxNumber) => taxNumber.substring(0, 8);

// The first seven digits of a base number weighted by 9, 7, 3, 1, 9, 7, 3;
// the check digit brings the sum to a multiple of 10.
bool _isValidBase(String base) {
  const weights = [9, 7, 3, 1, 9, 7, 3];
  var sum = 0;
  for (var i = 0; i < weights.length; i++) {
    sum += _digit(base, i) * weights[i];
  }
  return (10 - sum % 10) % 10 == _digit(base, 7);
}

int _digit(String digits, int index) => digits.codeUnitAt(index) - 0x30;
