import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a Hungarian account number: 2 or 3 blocks with right check digits', () {
    expect(parseBankAccount('11773016-11111018'), '11773016-11111018');
    expect(
      parseBankAccount(' 11773016 11111018 00000000 '),
      '11773016-11111018-00000000',
    );
    // A digit wrong: its block's check fails.
    expect(parseBankAccount('11773016-11111019'), isNull);
    expect(parseBankAccount('1177301611111'), isNull);
  });

  test('an IBAN: mod 97, in groups of four', () {
    expect(
      parseBankAccount('HU42117730161111101800000000'),
      'HU42 1177 3016 1111 1018 0000 0000',
    );
    expect(
      parseBankAccount('hu42 1177 3016 1111 1018 0000 0000'),
      'HU42 1177 3016 1111 1018 0000 0000',
    );
    expect(parseBankAccount('DE89 3704 0044 0532 0130 00'), isNotNull);
    expect(parseBankAccount('HU43117730161111101800000000'), isNull);
  });

  test('a SWIFT / BIC code: 8 or 11 characters', () {
    expect(parseSwift('otpvhuhb'), 'OTPVHUHB');
    expect(parseSwift('OTPVHUHBXXX'), 'OTPVHUHBXXX');
    expect(parseSwift('OTPV'), isNull);
    expect(parseSwift('OTPVHUHBXX'), isNull);
  });
}
