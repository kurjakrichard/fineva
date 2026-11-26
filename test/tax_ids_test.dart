import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseTaxId', () {
    test('accepts a number with the right check digit', () {
      // 8*1 + 3*2 + 9*3 + 1*4 + 9*5 + 2*6 = 102, 102 % 11 = 3
      expect(parseTaxId('8391920003'), '8391920003');
      expect(parseTaxId(' 8391 920 003 '), '8391920003');
    });

    test('refuses a wrong check digit, length or first digit', () {
      expect(parseTaxId('8391920004'), isNull);
      expect(parseTaxId('839192000'), isNull);
      expect(parseTaxId('83919200030'), isNull);
      // Same check digit, but a private person's number starts with 8.
      expect(parseTaxId('7391920003'), isNull);
      expect(parseTaxId('839192000x'), isNull);
      expect(parseTaxId(''), isNull);
    });
  });

  group('parseEuVatNumber', () {
    test('accepts HU and a valid base number, in any form', () {
      expect(parseEuVatNumber('HU10773381'), 'HU10773381');
      expect(parseEuVatNumber('hu 1077 3381'), 'HU10773381');
      expect(parseEuVatNumber('10773381'), 'HU10773381');
    });

    test('refuses a wrong check digit, length or country', () {
      expect(parseEuVatNumber('HU10773382'), isNull);
      expect(parseEuVatNumber('HU1077338'), isNull);
      expect(parseEuVatNumber('DE10773381'), isNull);
      expect(parseEuVatNumber(''), isNull);
    });

    test('is HU and the base number of the tax number', () {
      expect(taxNumberBase(parseTaxNumber('10773381-2-44')!), '10773381');
    });
  });

  group('parseTaxNumber', () {
    test('accepts a number with the right check digit, with or without '
        'dashes', () {
      expect(parseTaxNumber('10773381-2-44'), '10773381-2-44');
      expect(parseTaxNumber('10773381244'), '10773381-2-44');
      expect(parseTaxNumber(' 10773381 2 44 '), '10773381-2-44');
    });

    test('refuses a wrong check digit, VAT code or form', () {
      expect(parseTaxNumber('10773382-2-44'), isNull);
      expect(parseTaxNumber('10773381-6-44'), isNull);
      expect(parseTaxNumber('10773381-0-44'), isNull);
      expect(parseTaxNumber('10773381-2-4'), isNull);
      expect(parseTaxNumber('1077338-12-44'), isNull);
      expect(parseTaxNumber(''), isNull);
    });
  });
}
