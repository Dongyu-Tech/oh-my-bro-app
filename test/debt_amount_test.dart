import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/shared/debt/debt_amount.dart';

void main() {
  test('blank means "let them fill it in", not zero', () {
    expect(parseOptionalAmount(''), isNull);
    expect(parseOptionalAmount('   '), isNull);
  });

  test('a real number comes through', () {
    expect(parseOptionalAmount('500'), 500);
    expect(parseOptionalAmount('  500  '), 500);
    expect(parseOptionalAmount('1'), 1);
  });

  test('junk and non-positive values are rejected', () {
    // Nobody can meaningfully confirm owing zero or minus five.
    expect(() => parseOptionalAmount('abc'), throwsFormatException);
    expect(() => parseOptionalAmount('0'), throwsFormatException);
    expect(() => parseOptionalAmount('-5'), throwsFormatException);
    expect(() => parseOptionalAmount('12.5'), throwsFormatException);
  });
}
