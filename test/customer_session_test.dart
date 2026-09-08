import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muhajeerbooks/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'muhajeer_customer_name': 'Old customer',
      'muhajeer_customer_phone': '010-1234-5678',
      'muhajeer_customer_address': 'Private address',
    }),
  );

  test('Equivalent verified phone preserves address; another customer does not inherit it', () async {
    final state = AppState(backendConfigured: false);
    await state.initialize();
    await state.setAuthenticatedCustomer('Ali', '+821012345678');
    expect(state.savedCustomer['address'], 'Private address');
    await state.setAuthenticatedCustomer('Vali', '+821087654321');
    expect(state.savedCustomer['name'], 'Vali');
    expect(state.savedCustomer['address'], isEmpty);
    state.dispose();
  });

  test(
    'Logout removes saved identity and address from persistent preferences',
    () async {
      final state = AppState(backendConfigured: false);
      await state.initialize();
      await state.clearCustomerSession();
      expect(state.savedCustomer.values, everyElement(isEmpty));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('muhajeer_customer_phone'), isEmpty);
      expect(prefs.getString('muhajeer_customer_address'), isEmpty);
      state.dispose();
    },
  );
}
