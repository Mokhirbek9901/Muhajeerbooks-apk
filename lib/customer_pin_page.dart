import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

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
  bool creating = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppState>().savedCustomer;
    name = TextEditingController(text: saved['name'] ?? '');
    phone = TextEditingController(text: saved['phone'] ?? '');
    // New profiles create a PIN; returning users can switch to PIN login.
    creating = true;
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
    if (busy || formKey.currentState?.validate() != true) return;
    setState(() => busy = true);
    try {
      final state = context.read<AppState>();
      if (creating) {
        await state.enrollCustomerWithPin(
          name.text.trim(), phone.text.trim(), pin.text);
      } else {
        await state.loginPersonalPin(phone.text.trim(), pin.text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(creating
          ? 'Profil yaratildi, PIN xavfsiz saqlandi ✅'
          : 'Profilingiz boshqa telefonda ham ochildi ✅'),
      ));
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
    final state = context.watch<AppState>();
    if (state.pinSessionActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shaxsiy PIN')),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(padding: const EdgeInsets.all(22), child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 60),
              const SizedBox(height: 12),
              const Text('Profil himoyalangan',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${state.savedCustomer['name'] ?? ''}\n'
                   '${state.savedCustomer['phone'] ?? ''}',
                textAlign: TextAlign.center),
              const SizedBox(height: 18),
              const Text('Shu qurilmada PINni har buyurtmada yozish shart emas. '
                'Boshqa qurilmadan eski buyurtmalaringizni topish uchun PINingizni eslab qoling.',
                textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: busy ? null : () async {
                  setState(() => busy = true);
                  await state.signOutCustomer();
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Profildan chiqish'),
              ),
            ],
          )),
        )),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mening ma’lumotlarim')),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(22),
            children: [
              const Icon(Icons.password_outlined, size: 48),
              const SizedBox(height: 12),
              Text(creating ? 'Ism, telefon va PIN' : 'Boshqa qurilmadan kirish',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21,fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(creating
                ? 'Bir marta ism, telefon va 4 xonali PINni kiriting. '
                  'Keyingi buyurtmalarda avtomatik ishlatiladi. '
                  'Boshqa qurilmada buyurtmalaringizni topish uchun '
                  'PINni unutmang.'
                : 'Telefon raqamingiz va 4 xonali PINni yozing. SMS kelmaydi.',
                textAlign: TextAlign.center),
              const SizedBox(height: 22),
              if (creating) ...[
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ism', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v ?? '').trim().length < 2
                    ? 'Ismingizni kiriting' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon raqami',
                  hintText: '01012345678',
                  prefixIcon: Icon(Icons.phone_outlined)),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  return digits.length < 9 || digits.length > 13
                    ? 'Telefon raqamini to‘liq kiriting' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pin,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '4 xonali PIN',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                  counterText: ''),
                validator: (v) => RegExp(r'^[0-9]{4}$').hasMatch(v ?? '')
                    ? null : '4 ta raqam kiriting',
              ),
              if (creating) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'PINni qayta kiriting',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                    counterText: ''),
                  validator: (v) => v == pin.text
                      ? null : 'PINlar bir xil emas',
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(busy ? 'Tekshirilmoqda…' :
                    (creating ? 'PINni saqlash' : 'Kirish')),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: busy ? null : () => setState(() {
                  creating = !creating;
                  pin.clear();
                  confirm.clear();
                }),
                child: Text(creating
                  ? 'PINim bor — boshqa telefondan kirish'
                  : 'Yangi profil uchun PIN yaratish'),
              ),
              const SizedBox(height: 12),
              const Text('Muhim: PINni eslab qoling! SMS orqali tiklash mavjud emas. '
                'Sessiyadan chiqib ketganingizdan keyin eski profilni '
                'ismsiz va PINsiz ochib bo‘lmaydi. PINni xavfsiz saqlang.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      )),
    );
  }
}

 
/// One-time checkout gate; returns to the unfinished order after registration.
/// For offline demo/test mode there is no remote identity service to enroll in.
Future<bool> ensureCustomerCheckoutIdentity(BuildContext context) async {
  final current=context.read<AppState>();
  if (!current.backendConfigured || current.checkoutIdentityReady) return true;
  await Navigator.of(context).push<bool>(MaterialPageRoute(
    settings: const RouteSettings(name:'mb:checkout-profile'),
    builder: (_) => const CustomerPinPage(),
  ));
  return context.mounted && context.read<AppState>().checkoutIdentityReady;
}
