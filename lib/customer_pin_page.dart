import 'customer_form_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'customer_account_actions.dart';

/// SMS-free PIN-backed profile for placing orders and restoring access on another device.
/// A PIN does not prove ownership of a telephone number.
class CustomerPinPage extends StatefulWidget {
  const CustomerPinPage({super.key});

  @override
  State<CustomerPinPage> createState() => _CustomerPinPageState();
}

class _CustomerPinPageState extends State<CustomerPinPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  final pin = TextEditingController();
  final confirm = TextEditingController();
  // On a signed-out phone, open the returning-customer login first.
  // New customers can switch to the full name + phone + PIN form.
  bool creating = false;
  bool busy = false;
  bool editLoginPhone = false;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppState>().savedCustomer;
    name = TextEditingController(text: saved['name'] ?? '');
    phone = TextEditingController(text: saved['phone'] ?? '');
    // Never infer that a blank local profile is a brand-new account.
    // A signed-out returning customer should see Kirish immediately.
    creating = false;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    pin.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    CustomerFormScaffold.dismissKeyboard();
    if (busy || formKey.currentState?.validate() != true) return;
    setState(() => busy = true);
    try {
      final state = context.read<AppState>();
      if (creating) {
        await state.enrollCustomerWithPin(
          name.text.trim(),
          phone.text.trim(),
          pin.text,
        );
      } else {
        await state.loginPersonalPin(phone.text.trim(), pin.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            creating
                ? 'Profil yaratildi, PIN xavfsiz saqlandi ✅'
                : 'Profilingiz boshqa telefonda ham ochildi ✅',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.checkoutIdentityReady) {
      final savedName = (state.savedCustomer['name'] ?? '').trim();
      final savedPhone = (state.savedCustomer['phone'] ?? '').trim();
      return CustomerFormScaffold(
        appBar: AppBar(title: const Text('Mening ma’lumotlarim')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              shrinkWrap: true,
              padding: const EdgeInsets.all(22),
              children: [
                const Icon(Icons.lock_person_outlined, size: 56),
                const SizedBox(height: 14),
                const Text(
                  'Profilga kirilgansiz',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Ism'),
                  subtitle: Text(savedName),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Telefon raqami'),
                  subtitle: Text(savedPhone),
                ),
                const ListTile(
                  leading: Icon(Icons.password_outlined),
                  title: Text('Shaxsiy PIN'),
                  subtitle: Text('••••  •  himoyalangan'),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Bu telefonda PINni har safar kiritish shart emas. '
                  'Boshqa telefonda eski buyurtmalarni ochish uchun '
                  'telefon raqamingiz va PIN kerak.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final shouldSignOut = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              title: const Text('Profildan chiqilsinmi?'),
                              content: const Text(
                                'Bu qurilmadagi ism, telefon, manzil, '
                                'buyurtmalar va oldindan zakazlar tarixi '
                                'hamda shaxsiy savat yashiriladi va tozalanadi. '
                                'Serverdagi buyurtmalar o‘chmaydi: '
                                'oldingi telefon va PIN bilan qayta kirasiz.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: const Text('Bekor qilish'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: const Text('Chiqish'),
                                ),
                              ],
                            ),
                          );
                          if (shouldSignOut != true || !mounted) return;
                          setState(() => busy = true);
                          try {
                            await context.read<AppState>().signOutCustomer();
                            if (!mounted) return;
                            setState(() {
                              creating = false;
                              editLoginPhone = true;
                              name.clear();
                              phone.clear();
                              pin.clear();
                              confirm.clear();
                            });
                          } catch (error) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Chiqishda xato: $error'),
                                ),
                              );
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Profildan chiqish'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return CustomerFormScaffold(
      appBar: AppBar(title: const Text('Mening ma’lumotlarim')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: formKey,
            child: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              shrinkWrap: true,
              padding: const EdgeInsets.all(22),
              children: [
                const Icon(Icons.password_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  creating ? 'Yangi profil yaratish' : 'Profilga kirish',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  creating
                      ? 'Ismingiz, telefon raqamingiz va yangi 4 xonali PINni kiriting. '
                            'Agar bu raqamda oldin profil bo‘lsa, yangi PIN bilan uni '
                            'almashtirib bo‘lmaydi.'
                      : 'Oldin ro‘yxatdan o‘tgan bo‘lsangiz, telefon raqamingiz '
                            'va avvalgi PINni kiriting. Eski buyurtmalar shu '
                            'profil bilan ochiladi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                if (creating) ...[
                  TextFormField(
                    controller: name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Ism',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v ?? '').trim().length < 2
                        ? 'Ismingizni kiriting'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (!creating &&
                    phone.text.trim().isNotEmpty &&
                    !editLoginPhone) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_outlined),
                    title: Text(phone.text),
                    subtitle: const Text('Saqlangan raqam'),
                    trailing: TextButton(
                      onPressed: () => setState(() => editLoginPhone = true),
                      child: const Text('Boshqa raqam'),
                    ),
                  ),
                ] else
                  TextFormField(
                    controller: phone,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon raqami',
                      hintText: '01012345678',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      return digits.length < 9 || digits.length > 13
                          ? 'Telefon raqamini to‘liq kiriting'
                          : null;
                    },
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pin,
                  textInputAction: creating ? TextInputAction.next : TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!creating) submit();
                  },
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '4 xonali PIN',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                    counterText: '',
                  ),
                  validator: (v) => RegExp(r'^[0-9]{4}$').hasMatch(v ?? '')
                      ? null
                      : '4 ta raqam kiriting',
                ),
                if (creating) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submit(),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PINni qayta kiriting',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                      counterText: '',
                    ),
                    validator: (v) =>
                        v == pin.text ? null : 'PINlar bir xil emas',
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      busy
                          ? 'Tekshirilmoqda…'
                          : (creating ? 'PINni saqlash' : 'Kirish'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          creating = !creating;
                          editLoginPhone = false;
                          pin.clear();
                          confirm.clear();
                        }),
                  child: Text(
                    creating
                        ? 'Oldingi profilim bor — Kirish'
                        : 'Oldin PIN yaratmaganman — Yangi profil',
                  ),
                ),
                if (!creating) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => showPinRecovery(
                            context,
                            name: name.text,
                            phone: phone.text,
                          ),
                    child: const Text('PIN esimda yo‘q'),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Muhim: PINni eslab qoling! SMS orqali tiklash mavjud emas. '
                  'Boshqa qurilmada telefon raqami va PIN kerak bo‘ladi. '
                  'PIN ilovada ochiq ko‘rsatilmaydi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-time checkout gate; returns to the unfinished order after registration.
/// For offline demo/test mode there is no remote identity service to enroll in.
Future<bool> ensureCustomerCheckoutIdentity(BuildContext context) async {
  final current = context.read<AppState>();
  if (!current.backendConfigured || current.checkoutIdentityReady) return true;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'mb:checkout-profile'),
      builder: (_) => const CustomerPinPage(),
    ),
  );
  return context.mounted && context.read<AppState>().checkoutIdentityReady;
}
