import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'customer_account_actions.dart';
import 'customer_form_scaffold.dart';

/// Customer contact details. Device access is created automatically, without a PIN.
/// The historical class name is retained for existing navigation routes.
class CustomerPinPage extends StatefulWidget {
  const CustomerPinPage({super.key});
  @override
  State<CustomerPinPage> createState() => _CustomerPinPageState();
}

class _CustomerPinPageState extends State<CustomerPinPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppState>().savedCustomer;
    name = TextEditingController(text: saved['name'] ?? '');
    phone = TextEditingController(text: saved['phone'] ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    CustomerFormScaffold.dismissKeyboard();
    if (busy || formKey.currentState?.validate() != true) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>().saveCustomerWithoutPin(
        name.text.trim(), phone.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ma’lumotlaringiz saqlandi ✅')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = context.watch<AppState>().checkoutIdentityReady;
    return CustomerFormScaffold(
      appBar: AppBar(title: const Text('Mening ma’lumotlarim')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              shrinkWrap: true,
              padding: const EdgeInsets.all(22),
              children: [
                const Icon(Icons.person_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Buyurtma uchun ma’lumotlar',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Ismingiz va telefon raqamingizni kiriting. '
                  'Keyingi buyurtmalarda shu qurilmada saqlanadi.',
                  textAlign: TextAlign.center),
                const SizedBox(height: 22),
                TextFormField(
                  controller: name,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Ism',
                    prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Ismingizni kiriting' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => submit(),
                  maxLength: 32,
                  decoration: const InputDecoration(labelText: 'Telefon raqami',
                    hintText: '01012345678', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length < 9 || digits.length > 13
                        ? 'Telefon raqamini to‘liq kiriting' : null;
                  },
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Saqlanmoqda…' : 'Saqlash va davom etish'),
                ),
                TextButton(
                  onPressed: busy ? null : () => showCustomerHistoryHelp(context),
                  child: const Text('Boshqa telefondagi buyurtmalarim'),
                ),
                if (ready) OutlinedButton.icon(
                  onPressed: busy ? null : () async {
                    final confirmed = await confirmCustomerSignOut(context);
                    if (!confirmed || !mounted) return;
                    setState(() => busy = true);
                    try {
                      await context.read<AppState>().signOutCustomer();
                      name.clear();
                      phone.clear();
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Profildan chiqish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> ensureCustomerCheckoutIdentity(BuildContext context) async {
  final state = context.read<AppState>();
  if (!state.backendConfigured) return true;
  await state.restoreCustomerDevice();
  if (!context.mounted) return false;
  if (state.checkoutIdentityReady) return true;
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const CustomerPinPage()),
  );
  return result == true && state.checkoutIdentityReady;
}
