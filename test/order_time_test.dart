import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/web_preorders.dart';

void main() {
  const koreaRequired = bool.fromEnvironment('REQUIRE_KOREA_TIME');
  test('order timestamps become device local time without changing the instant', () {
    final order = ShopOrder.fromMap({
      'id': 'time-test', 'created_at': '2026-10-20T12:28:43Z',
      'payment_submitted_at': '2026-10-20T12:29:00+00:00',
      'tracking_updated_at': '2026-10-20T18:10:00Z',
      'prepared_at': '2026-10-20T15:01:00Z',
    });
    expect(order.createdAt.isUtc, isFalse);
    expect(order.createdAt.toUtc(), DateTime.utc(2026, 10, 20, 12, 28, 43));
    expect(order.paymentSubmittedAt!.isUtc, isFalse);
    expect(order.trackingUpdatedAt!.isUtc, isFalse);
    expect(order.preparedAt!.isUtc, isFalse);
    final cache = order.toMap();
    expect(cache['created_at'], '2026-10-20T12:28:43.000Z');
    expect(ShopOrder.fromMap(cache).createdAt, order.createdAt);
    if (koreaRequired) {
      expect(order.createdAt.timeZoneOffset, const Duration(hours: 9));
      expect(DateFormat('yyyy.MM.dd HH:mm').format(order.createdAt), '2026.10.20 21:28');
      expect(order.trackingUpdatedAt!.day, 21);
      expect(order.trackingUpdatedAt!.hour, 3);
      expect(order.preparedAt!.day, 21);
    }
  });
  test('Korea offset inputs do not get shifted twice', () {
    final utc = ShopOrder.fromMap({'created_at': '2026-10-20T18:18:25Z'});
    final korea = ShopOrder.fromMap({'created_at': '2026-10-21T03:18:25+09:00'});
    expect(utc.createdAt, korea.createdAt);
    if (koreaRequired) {
      expect(utc.createdAt.day, 21);
      expect(utc.createdAt.hour, 3);
      expect(webPreorderTime('2026-10-20T18:18:25Z'), '2026.10.21 03:18');
    }
  });
  test('existing local cached order dates remain local', () {
    final order = ShopOrder.fromMap({'created_at': '2026-10-21T03:18:25'});
    expect(order.createdAt, DateTime(2026, 10, 21, 3, 18, 25));
  });
}
