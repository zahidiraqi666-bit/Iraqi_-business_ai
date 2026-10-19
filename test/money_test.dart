import 'package:flutter_test/flutter_test.dart';
import 'package:iraqi_business_ai/labels.dart';
import 'package:iraqi_business_ai/money.dart';

void main() {
  group('Money.format', () {
    test('IQD whole dinars with grouping', () {
      expect(Money.format(1250000, 'IQD'), '1,250,000 د.ع');
      expect(Money.format(0, 'IQD'), '0 د.ع');
      expect(Money.format(999, 'IQD'), '999 د.ع');
      expect(Money.format(1000, 'IQD'), '1,000 د.ع');
    });

    test('USD cents', () {
      expect(Money.format(1250, 'USD'), '12.50 \$');
      expect(Money.format(5, 'USD'), '0.05 \$');
      expect(Money.format(123456789, 'USD'), '1,234,567.89 \$');
    });

    test('negative and null', () {
      expect(Money.format(-2500, 'IQD'), '-2,500 د.ع');
      expect(Money.format(null, 'IQD'), '—');
    });
  });

  group('Money.parse', () {
    test('IQD', () {
      expect(Money.parse('25,000', 'IQD'), 25000);
      expect(Money.parse('٢٥٠٠٠', 'IQD'), 25000);
      expect(Money.parse('۱۰۰۰', 'IQD'), 1000);
      expect(Money.parse('12.5', 'IQD'), isNull);
      expect(Money.parse('', 'IQD'), isNull);
      expect(Money.parse('-5', 'IQD'), isNull);
      expect(Money.parse('abc', 'IQD'), isNull);
    });

    test('USD', () {
      expect(Money.parse('12.5', 'USD'), 1250);
      expect(Money.parse('12.05', 'USD'), 1205);
      expect(Money.parse('12', 'USD'), 1200);
      expect(Money.parse('1,234.56', 'USD'), 123456);
      expect(Money.parse('1.234', 'USD'), isNull);
    });

    test('round trip through toInput', () {
      for (final v in [0, 5, 1250, 99999]) {
        expect(Money.parse(Money.toInput(v, 'USD'), 'USD'), v);
        expect(Money.parse(Money.toInput(v, 'IQD'), 'IQD'), v);
      }
    });
  });

  group('Labels', () {
    test('server error codes map to Arabic', () {
      expect(Labels.error(Exception('P0001: forbidden')),
          Labels.errors['forbidden']);
      expect(Labels.warning('negative_margin'), isNot('negative_margin'));
      expect(Labels.warning('unknown_code'), 'unknown_code');
    });
  });
}
