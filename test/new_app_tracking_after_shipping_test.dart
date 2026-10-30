import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';

ShopOrder shipment({
  String source = 'app',
  String status = 'shipping',
  String deliveryType = '택배',
  String tracking = '',
  bool enteredByAdmin = false,
  DateTime? createdAt,
}) => ShopOrder.fromMap({
  'id': 'tracking-test',
  'created_at': (createdAt ?? newDispatchTrackingOrderCutoff.add(
    const Duration(minutes: 1),
  )).toUtc().toIso8601String(),
  'source': source,
  'status': status,
  'delivery_type': deliveryType,
  'tracking_number': tracking,
  'entered_by_admin': enteredByAdmin,
});

void main() {
  test('only new app-placed courier shipments without tracking enter reminder', () {
    expect(isNewAppShippedWithoutTracking(shipment()), isTrue);
    expect(isNewAppShippedWithoutTracking(shipment(
      createdAt: newDispatchTrackingOrderCutoff,
    )), isTrue);

    expect(isNewAppShippedWithoutTracking(shipment(
      createdAt: newDispatchTrackingOrderCutoff.subtract(
        const Duration(seconds: 1),
      ),
    )), isFalse, reason: 'Historical orders must stay excluded');
    expect(isNewAppShippedWithoutTracking(shipment(
      status: 'accepted',
    )), isFalse, reason: 'Only after Jo‘natildi');
    expect(isNewAppShippedWithoutTracking(shipment(
      status: 'paid',
    )), isFalse);
    expect(isNewAppShippedWithoutTracking(shipment(
      status: 'cancelled',
    )), isFalse);
    expect(isNewAppShippedWithoutTracking(shipment(
      tracking: '1234567890',
    )), isFalse, reason: 'Tracking entered, remove from reminder');
    expect(isNewAppShippedWithoutTracking(shipment(
      source: 'instagram',
    )), isFalse);
    expect(isNewAppShippedWithoutTracking(shipment(
      source: 'telegram',
    )), isFalse);
    expect(isNewAppShippedWithoutTracking(shipment(
      enteredByAdmin: true,
    )), isFalse, reason: 'Staff orders are not app customer orders');
    expect(isNewAppShippedWithoutTracking(shipment(
      deliveryType: '경산 직접수령',
    )), isFalse);
    expect(isNewAppShippedWithoutTracking(shipment(
      deliveryType: 'pickup',
    )), isFalse);
  });

  test('manual order origin survives copy and serialization', () {
    final order = shipment(enteredByAdmin: true);
    expect(order.enteredByAdmin, isTrue);
    expect(ShopOrder.fromMap(order.toMap()).enteredByAdmin, isTrue);
    expect(order.copyWith(trackingNumber: '01010').enteredByAdmin, isTrue);
    expect(ShopOrder.fromMap(shipment().toMap()).enteredByAdmin, isFalse);
  });
}
