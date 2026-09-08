from pathlib import Path


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


state_path = Path('lib/app_state.dart')
s = state_path.read_text(encoding='utf-8')

# New production baseline: old test orders/notices in browser/APK storage must not
# appear after the central database reset.
s = replace_once(
    s,
    "  static const _ordersKey = 'muhajeer_orders_v3';",
    "  static const _ordersKey = 'muhajeer_orders_v4';",
    'local order history version',
)
s = replace_once(
    s,
    "  static const _customerNoticesKey = 'muhajeer_customer_notices_v1';",
    "  static const _customerNoticesKey = 'muhajeer_customer_notices_v2';",
    'local notice history version',
)

# Checkout totals are server-authoritative. Mirror the exact 4+ free-delivery
# rule locally instead of trusting any caller-supplied fee.
place_start = s.find('  Future<String> placeOrder({')
place_end = s.find('\n  Future<List<ShopOrder>> fetchOrders()', place_start)
if place_start < 0 or place_end < 0:
    raise SystemExit('placeOrder boundaries not found')
place = s[place_start:place_end]
place = replace_once(
    place,
    "    final subtotal = cartSubtotal;\n    final total = subtotal + deliveryFee;",
    "    if (_backend != null && paymentProof == null) {\n"
    "      throw StateError('To‘lov chekini tanlang.');\n"
    "    }\n\n"
    "    final subtotal = cartSubtotal;\n"
    "    final safeDeliveryFee = cartCount >= 4 ? 0 : AppState.deliveryFee;\n"
    "    final total = subtotal + safeDeliveryFee;",
    'checkout server-aligned delivery',
)
place = place.replace('deliveryFee: deliveryFee,', 'deliveryFee: safeDeliveryFee,')
s = s[:place_start] + place + s[place_end:]

# Same customer's order history remains visible whether they type Korean/Uzbek
# phone numbers in local or international form.
customer_start = s.find('  Future<List<ShopOrder>> customerOrdersByPhone(String phone) async {')
customer_end = s.find('\n  Future<void> markCustomerNoticesRead()', customer_start)
if customer_start < 0 or customer_end < 0:
    raise SystemExit('customerOrdersByPhone boundaries not found')
customer_fn = '''  Future<List<ShopOrder>> customerOrdersByPhone(String phone) async {
    final key = _customerPhoneKey(phone);
    if (key.isEmpty) return [];

    _localOrders
      ..clear()
      ..addAll(await _local.loadOrders());

    if (_backend != null && _localOrders.isNotEmpty) {
      try {
        final uuidIds = _localOrders
            .map((o) => o.id)
            .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
            .toList();
        final statuses = await _backend!.fetchOrderStatuses(uuidIds);
        for (var i = 0; i < _localOrders.length; i++) {
          final row = statuses[_localOrders[i].id];
          if (row == null) continue;
          _localOrders[i] = _localOrders[i].copyWith(
            status: (row['status'] ?? _localOrders[i].status).toString(),
            stockReserved:
                row['stock_reserved'] as bool? ?? _localOrders[i].stockReserved,
          );
        }
        await _local.saveOrders(_localOrders);
      } catch (_) {
        // Temporary network failure: keep the last known local order history.
      }
    }

    return _localOrders.where((o) => _customerPhoneKey(o.phone) == key).toList();
  }
'''
s = s[:customer_start] + customer_fn + s[customer_end:]

helper_anchor = '''  static String _normalize(String input) => input
'''
if helper_anchor not in s:
    raise SystemExit('phone helper anchor not found')
phone_helper = '''  static String _customerPhoneKey(String raw) {
    var digits = raw.replaceAll(RegExp(r'\\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 12 && digits.startsWith('998')) return digits;
    if (digits.length == 9 && !digits.startsWith('0')) return '998$digits';
    if (digits.length == 11 && digits.startsWith('010')) {
      return '82${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('8210')) return digits;
    return '';
  }

'''
s = s.replace(helper_anchor, phone_helper + helper_anchor, 1)
state_path.write_text(s, encoding='utf-8')

# Remove two obsolete source files that were not imported by the production app.
# One contained an old Woori Bank checkout mock, which must never be mistaken for
# the real Toss Bank checkout.
for stale in ('lib/checkout_page.dart', 'lib/main.dart2'):
    path = Path(stale)
    if path.exists():
        path.unlink()

print('Final app hardening prepared: clean production history, exact phone matching, safe checkout totals.')
