/// Opaque credentials. A contact phone number is never authorization.
class CustomerSession {
  static String token = '';
  static String professionalToken = '';

  static bool isDevice(String value) =>
      RegExp(r'^device:[a-f0-9]{64}$').hasMatch(value);

  // FCM accepts the durable device credential directly. It must never be
  // wrapped in a temporary PIN compatibility session that disappears on return.
  static const deviceActions = <String>{
    'customer_device_recovery_request', 'customer_pin_profile', 'customer_pin_logout', 'customer_pin_preorders',
    'customer_release_preorder', 'customer_release_preorders',
    'customer_release_link_orders', 'customer_release_my_orders',
    'customer_release_quote', 'customer_release_order', 'customer_release_inbox',
    'customer_release_push_subscribe', 'customer_release_receipt',
    'customer_release_apns', 'customer_release_delete_profile',
    'customer_release_reviews', 'customer_release_review_action',
    'customer_web_preorder_checkout', 'customer_web_preorder_delivery',
    'customer_preorder_submit', 'customer_preorder_balance_list',
    'customer_preorder_discovery', 'customer_preorder_activity_list',
    'customer_preorder_event_list', 'customer_book_review_submit',
  };

  /// Explicit empty sessions belong to professional checkout and must stay empty.
  static String deviceFor(String action, Map<String, dynamic> params) {
    if (!deviceActions.contains(action)) return '';
    final candidate = params.containsKey('p_session')
        ? '${params['p_session'] ?? ''}'
        : token;
    return isDevice(candidate) ? candidate : '';
  }
}
