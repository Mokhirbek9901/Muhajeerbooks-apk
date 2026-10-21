import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_order_add_policy.dart';

void main() {
  test('only new app orders are eligible', () {
    expect(WebOrderAddPolicy.mayAdd(status: 'new', isAppOrder: true), isTrue);
    for (final status in ['accepted', 'prepared', 'preparing', 'shipping', 'done', 'cancelled']) {
      expect(WebOrderAddPolicy.mayAdd(status: status, isAppOrder: true), isFalse);
    }
    expect(WebOrderAddPolicy.mayAdd(status: 'new', isAppOrder: false), isFalse);
  });

  test('accepted order reports clear message', () {
    expect(WebOrderAddPolicy.blockedReason('accepted'),
      'Buyurtmangiz qabul qilingan. Endi unga kitob qo‘shib bo‘lmaydi');
  });

  test('four books qualify for free delivery', () {
    expect(WebOrderAddPolicy.shippingFee(totalQuantity: 3, localGyeongsan: false), 4000);
    expect(WebOrderAddPolicy.shippingFee(totalQuantity: 4, localGyeongsan: false), 0);
    expect(WebOrderAddPolicy.shippingFee(totalQuantity: 1, localGyeongsan: true), 0);
  });

  test('already paid amount is deducted but never silently increased', () {
    expect(WebOrderAddPolicy.additionalPayment(revisedTotal: 54000, verifiedPaidAmount: 30000), 24000);
    expect(WebOrderAddPolicy.additionalPayment(revisedTotal: 30000, verifiedPaidAmount: 32000), 0);
  });
}
