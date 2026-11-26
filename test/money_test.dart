import 'package:fineva/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

// intl uses non-breaking spaces between groups and before the symbol.
String plain(String text) => text.replaceAll(' ', ' ');

void main() {
  test('parses typed amounts into the smallest unit', () {
    expect(Currency.huf.parse('1 234'), 1234);
    expect(Currency.huf.parse('1500'), 1500);
    expect(Currency.eur.parse('12,34'), 1234);
    expect(Currency.eur.parse('12.3'), 1230);
    expect(Currency.eur.parse('-5'), -500);
    expect(Currency.eur.parse('abc'), isNull);
    expect(Currency.eur.parse('1,2,3'), isNull);
    expect(Currency.eur.parse(''), isNull);
  });

  test('formats amounts in the app language', () {
    expect(plain(Currency.huf.format(1500, 'hu')), '1 500 Ft');
    expect(plain(Currency.eur.format(123456, 'hu')), '1 234,56 €');
    expect(Currency.eur.format(123456, 'en'), '€1,234.56');
    expect(Currency.usd.format(-250, 'en'), r'-$2.50');
  });

  test('editable text round-trips', () {
    expect(Currency.eur.toInput(123450), '1234.50');
    expect(Currency.huf.toInput(1234), '1234');
    expect(Currency.eur.parse(Currency.eur.toInput(99)), 99);
  });

  test('unknown currency code falls back to HUF', () {
    expect(Currency.fromCode('XYZ'), Currency.huf);
    expect(Currency.fromCode('EUR'), Currency.eur);
  });
}
