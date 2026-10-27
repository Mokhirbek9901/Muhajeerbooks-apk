import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';

void main() {
  test('professional quote and submit use only admin token (no customer PIN)', () {
    const customerSession='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    expect(checkoutPinSessionForMode(
      professional:true,customerSession:customerSession),isEmpty);
    expect(checkoutPinSessionForMode(
      professional:false,customerSession:customerSession),customerSession);
  });
  test('professional mode also works when no customer profile is logged in', () {
    expect(checkoutPinSessionForMode(
      professional:true,customerSession:''),isEmpty);
  });
}
