import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'uzbek_customer_style.dart';

/// SMS login is intentionally web-only for now. Native releases keep their
/// current behaviour until they are explicitly updated later.
bool get customerSmsLoginAvailable => kIsWeb;

bool get customerSmsSessionActive {
  if (!kIsWeb) return false;
  final user = Supabase.instance.client.auth.currentUser;
  return user != null && (user.phone ?? '').trim().isNotEmpty;
}

Future<void> openCustomerSmsAccount(BuildContext context) async {
  if (!kIsWeb) return;
  final state = context.read<AppState>();
  final loggedIn = state.customerVerified && customerSmsSessionActive;
  if (loggedIn) {
    await _showCustomerAccountSheet(context);
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'mb:web-sms-login'),
      builder: (_) => const CustomerSmsLoginPage(),
    ),
  );
}

Future<void> _showCustomerAccountSheet(BuildContext context) async {
  final state = context.read<AppState>();
  final customer = state.savedCustomer;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: UzbekCustomerColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: UzbekCustomerColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                CircleAvatar(
                  backgroundColor: UzbekCustomerColors.goldSoft,
                  foregroundColor: UzbekCustomerColors.navy,
                  child: Icon(Icons.verified_user_rounded),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hisobingiz',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: UzbekCustomerColors.navy,
                        ),
                      ),
                      Text('SMS orqali tasdiqlangan'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _AccountLine(
              icon: Icons.person_outline_rounded,
              label: 'Ism',
              value: (customer['name'] ?? '').trim(),
            ),
            const SizedBox(height: 10),
            _AccountLine(
              icon: Icons.phone_outlined,
              label: 'Telefon',
              value: (customer['phone'] ?? '').trim(),
            ),
            const SizedBox(height: 10),
            _AccountLine(
              icon: Icons.location_on_outlined,
              label: 'Manzil',
              value: (customer['address'] ?? '').trim(),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                await sheetContext.read<AppState>().signOutCustomer();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Hisobdan chiqish'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AccountLine extends StatelessWidget {
  const _AccountLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: UzbekCustomerColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: UzbekCustomerColors.teal, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: UzbekCustomerColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'Kiritilmagan' : value,
                style: const TextStyle(
                  color: UzbekCustomerColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CustomerSmsLoginPage extends StatefulWidget {
  const CustomerSmsLoginPage({super.key});

  @override
  State<CustomerSmsLoginPage> createState() => _CustomerSmsLoginPageState();
}

class _CustomerSmsLoginPageState extends State<CustomerSmsLoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  final _code = TextEditingController();

  bool _codeSent = false;
  bool _sending = false;
  bool _verifying = false;
  String _normalizedPhone = '';
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppState>().savedCustomer;
    _name = TextEditingController(text: saved['name'] ?? '');
    _phone = TextEditingController(text: _displayPhone(saved['phone'] ?? ''));
    _address = TextEditingController(text: saved['address'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  String _displayPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8210') && digits.length == 12) {
      return '0${digits.substring(2)}';
    }
    if (digits.startsWith('998') && digits.length == 12) return digits;
    return digits;
  }

  String? _normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 11 && digits.startsWith('010')) {
      return '+82${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('8210')) {
      return '+$digits';
    }
    if (digits.length == 12 && digits.startsWith('998')) {
      return '+$digits';
    }
    if (digits.length == 9 && !digits.startsWith('0')) {
      return '+998$digits';
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final normalized = _normalizePhone(_phone.text);
    if (normalized == null) {
      setState(() => _error = 'Koreya 010 yoki O‘zbekiston +998 raqamini to‘liq kiriting.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _client.auth.signInWithOtp(phone: normalized);
      if (!mounted) return;
      setState(() {
        _normalizedPhone = normalized;
        _codeSent = true;
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'SMS yuborilmadi: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final token = _code.text.replaceAll(RegExp(r'\D'), '');
    if (token.length != 6) {
      setState(() => _error = 'SMS orqali kelgan 6 xonali kodni kiriting.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.sms,
        token: token,
        phone: _normalizedPhone,
      );
      if (response.session == null) {
        throw const AuthException('SMS tasdiqlash yakunlanmadi.');
      }

      final cleanName = _name.text.trim();
      final cleanAddress = _address.text.trim();
      final state = context.read<AppState>();
      // Keep address in the same customer profile that Checkout already uses.
      state.savedCustomer = {
        'name': cleanName,
        'phone': _normalizedPhone,
        'address': cleanAddress,
      };
      await state.setAuthenticatedCustomer(
        cleanName,
        _normalizedPhone,
        verified: true,
      );

      // Customer analytics should never block a successful login.
      try {
        await _client.functions.invoke(
          'customer-rpc',
          body: {
            'name': 'customer_register_free',
            'params': {
              'p_name': cleanName,
              'p_phone': _normalizedPhone,
            },
          },
        );
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hisobga muvaffaqiyatli kirdingiz ✅')),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Kod tasdiqlanmadi: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(_codeSent ? 'SMS tasdiqlash' : 'Hisobga kirish'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: UzbekCustomerColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10173F4A),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 31,
                      backgroundColor: UzbekCustomerColors.goldSoft,
                      foregroundColor: UzbekCustomerColors.navy,
                      child: Icon(Icons.person_add_alt_1_rounded, size: 31),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _codeSent ? 'Telefonni tasdiqlang' : 'Muhajeer hisobingiz',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: UzbekCustomerColors.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _codeSent
                          ? '$_normalizedPhone raqamiga kelgan 6 xonali SMS kodni kiriting.'
                          : 'Ism, telefon va manzilingizni kiriting. Telefon SMS orqali bir marta tasdiqlanadi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: UzbekCustomerColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (!_codeSent) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Ism',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Ismingizni kiriting.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Telefon raqam',
                          hintText: '01012345678',
                          helperText: 'Koreya 010 yoki O‘zbekiston +998 raqami',
                          prefixIcon: Icon(Icons.phone_iphone_rounded),
                        ),
                        validator: (value) => _normalizePhone(value ?? '') == null
                            ? 'Telefon raqamini to‘liq kiriting.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Manzil',
                          hintText: 'Masalan: 경상북도 경산시 ..., 808호',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) => (value ?? '').trim().length < 5
                            ? 'Manzilingizni kiriting.'
                            : null,
                        onFieldSubmitted: (_) => _sendCode(),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _sending ? null : _sendCode,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sms_outlined),
                        label: Text(_sending ? 'Yuborilmoqda...' : 'SMS kod yuborish'),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: '6 xonali SMS kod',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                        onFieldSubmitted: (_) => _verifyCode(),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _verifying ? null : _verifyCode,
                        icon: _verifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_verifying ? 'Tekshirilmoqda...' : 'Kirish'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () {
                                _code.clear();
                                setState(() {
                                  _codeSent = false;
                                  _error = null;
                                });
                              },
                        child: const Text('Ma’lumotlarni o‘zgartirish'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFCBCB)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Buyurtma berish uchun hisobga kirish majburiy emas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: UzbekCustomerColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
