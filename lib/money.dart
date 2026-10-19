/// Money is stored as integer minor units: IQD in whole dinars, USD in cents.
/// These helpers only format and parse; all calculations happen on the server.
class Money {
  static int decimals(String currency) => currency == 'USD' ? 2 : 0;

  static String symbol(String currency) => currency == 'USD' ? '\$' : 'د.ع';

  /// 1250000 IQD -> "1,250,000 د.ع" ; 1250 USD -> "12.50 $"
  static String format(num? minor, String currency) {
    if (minor == null) return '—';
    final d = decimals(currency);
    final negative = minor < 0;
    final abs = minor.abs().round();
    String whole;
    String frac = '';
    if (d == 0) {
      whole = abs.toString();
    } else {
      whole = (abs ~/ 100).toString();
      frac = '.${(abs % 100).toString().padLeft(2, '0')}';
    }
    final grouped = _group(whole);
    return '${negative ? '-' : ''}$grouped$frac ${symbol(currency)}';
  }

  static String _group(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      b.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) b.write(',');
    }
    return b.toString();
  }

  /// Parses user input ("25,000", "12.5", Arabic digits) into minor units.
  /// Returns null when the text is not a valid non-negative amount.
  static int? parse(String input, String currency) {
    var s = normalizeDigits(input).replaceAll(',', '').replaceAll('٬', '').trim();
    s = s.replaceAll('٫', '.');
    if (s.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;
    final d = decimals(currency);
    final parts = s.split('.');
    final whole = int.parse(parts[0]);
    if (d == 0) {
      if (parts.length > 1 && int.parse(parts[1]) != 0) return null;
      return whole;
    }
    var frac = parts.length > 1 ? parts[1] : '';
    if (frac.length > d) return null;
    frac = frac.padRight(d, '0');
    return whole * 100 + int.parse(frac);
  }

  /// Converts Arabic-Indic and Persian digits to ASCII.
  static String normalizeDigits(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final a = arabic.indexOf(ch);
      final p = persian.indexOf(ch);
      if (a >= 0) {
        b.write(a);
      } else if (p >= 0) {
        b.write(p);
      } else {
        b.write(ch);
      }
    }
    return b.toString();
  }

  /// Minor units -> plain editable text (no grouping, no symbol).
  static String toInput(int? minor, String currency) {
    if (minor == null) return '';
    if (decimals(currency) == 0) return minor.toString();
    return '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
  }

  static int? parseInt(String input) {
    final s = normalizeDigits(input).replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }
}
