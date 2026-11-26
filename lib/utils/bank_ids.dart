/// [text] as a bank account number in its stored form, or null if it isn't
/// one: a Hungarian one (GIRO: 2 or 3 blocks of 8 digits, each block's
/// check digit right) as 12345678-12345678[-12345678], or an IBAN (country,
/// check digits, up to 30 letters and digits, mod 97 right) in groups of
/// four: HU42 1177 3016 1111 1018 0000 0000. Spaces and dashes are ignored.
String? parseBankAccount(String text) {
  final compact = text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (RegExp(r'^\d{16}$|^\d{24}$').hasMatch(compact)) {
    final blocks = [
      for (var i = 0; i < compact.length; i += 8) compact.substring(i, i + 8),
    ];
    return blocks.every(_giroBlockOk) ? blocks.join('-') : null;
  }
  if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$').hasMatch(compact)) {
    return null;
  }
  // The first four characters to the end, letters as 10..35, mod 97 = 1.
  final moved = compact.substring(4) + compact.substring(0, 4);
  var rest = 0;
  for (final char in moved.codeUnits) {
    final value = char >= 65 ? char - 55 : char - 48;
    rest = (rest * (value >= 10 ? 100 : 10) + value) % 97;
  }
  if (rest != 1) return null;
  return [
    for (var i = 0; i < compact.length; i += 4)
      compact.substring(i, i + 4 > compact.length ? compact.length : i + 4),
  ].join(' ');
}

/// A GIRO block: the digits weighted 9, 7, 3, 1, ... add up to a multiple
/// of 10.
bool _giroBlockOk(String block) {
  const weights = [9, 7, 3, 1, 9, 7, 3, 1];
  var sum = 0;
  for (var i = 0; i < 8; i++) {
    sum += (block.codeUnitAt(i) - 48) * weights[i];
  }
  return sum % 10 == 0;
}

/// [text] as a SWIFT / BIC code (OTPVHUHB, or with a branch OTPVHUHBXXX) in
/// capitals, or null if it isn't one.
String? parseSwift(String text) {
  final code = text.trim().toUpperCase();
  return RegExp(r'^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$').hasMatch(code)
      ? code
      : null;
}
