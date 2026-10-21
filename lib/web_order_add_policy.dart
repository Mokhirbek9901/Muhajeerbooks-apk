/// Web-only policy primitives. All mutating operations MUST enforce the same
/// rules again on the server while locking the order row.
class WebOrderAddPolicy {
  const WebOrderAddPolicy._();

  static bool mayAdd({required String status, required bool isAppOrder}) =>
      isAppOrder && status.trim().toLowerCase() == 'new';

  static String blockedReason(String status) {
    switch (status.trim().toLowerCase()) {
      case 'accepted':
      case 'qabul qilindi':
      case 'preparing':
      case 'prepared':
      case 'tayyorlandi':
        return 'Buyurtmangiz qabul qilingan. Endi unga kitob qo‘shib bo‘lmaydi';
      case 'shipping':
      case 'shipped':
      case 'done':
      case 'cancelled':
      case 'canceled':
      case 'bekor':
        return 'Bu buyurtmaga endi kitob qo‘shib bo‘lmaydi';
      default:
        return 'Buyurtma holatini tekshirib bo‘lmadi. Qayta urinib ko‘ring';
    }
  }

  /// UI estimate only. The server must derive the authoritative amount from
  /// persisted payment ledger, product prices and delivery rules.
  static int additionalPayment({
    required int revisedTotal,
    required int verifiedPaidAmount,
  }) {
    if (revisedTotal < 0 || verifiedPaidAmount < 0) {
      throw ArgumentError('Summalar manfiy bo‘lishi mumkin emas');
    }
    return revisedTotal > verifiedPaidAmount
        ? revisedTotal - verifiedPaidAmount
        : 0;
  }

  static int shippingFee({
    required int totalQuantity,
    required bool localGyeongsan,
    int ordinaryFee = 4000,
  }) {
    if (totalQuantity < 0 || ordinaryFee < 0) {
      throw ArgumentError('Noto‘g‘ri yetkazib berish ma’lumoti');
    }
    return localGyeongsan || totalQuantity >= 4 ? 0 : ordinaryFee;
  }
}
