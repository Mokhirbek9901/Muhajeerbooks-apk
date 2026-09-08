import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/customer_identity.dart';

void main() {
  test('Korean local and international formats identify the same customer', () {
    for (final phone in [
      '010-1234-5678',
      '010 1234 5678',
      '1012345678',
      '+82 10 1234 5678',
      '821012345678',
    ]) {
      expect(normalizeCustomerPhone(phone), '+821012345678');
    }
  });
  test('Explicit international numbers remain international', () {
    expect(normalizeCustomerPhone('+998 90 123 45 67'), '+998901234567');
  });
  test(
    'Reject malformed, incomplete and excessive numbers before requesting SMS',
    () {
      for (final phone in [
        '',
        'hello01012345678',
        '010123',
        '+8201012345678',
        '++821012345678',
        '82+1012345678',
        '+0123456789',
        '+1234567890123456',
        '12345678',
        '010123456789',
      ]) {
        expect(normalizeCustomerPhone(phone), isNull, reason: phone);
      }
    },
  );
}
