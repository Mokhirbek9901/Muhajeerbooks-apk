import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'brand.dart';
import 'design_system.dart';
import 'store_ui.dart';

/// Phone OTP is ready in the app. Keep this false until a Supabase SMS provider
/// is enabled, so customers are never locked out by missing third-party SMS
/// credentials. Enable at build time with --dart-define=REQUIRE_PHONE_AUTH=true.
const bool requirePhoneAuth = bool.fromEnvironment(
  'REQUIRE_PHONE_AUTH',
  defaultValue: false,
);

class CustomerAuthGate extends StatefulWidget {
  const CustomerAuthGate({super.key});

  @override
  State<CustomerAuthGate> createState() => _CustomerAuthGateState();
}

class _CustomerAuthGateState extends State<CustomerAuthGate> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  StreamSubscription<AuthState>? _authSub;
  bool sending = false;
  bool verifying = false;
  bool codeSent = false;
  String normalizedPhone = '';
  String? error;

  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSub = client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
    if (client.auth.currentSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateExisting());
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    name.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  String _normalizeKoreanPhone(String input) {
    final raw = input.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (raw.startsWith('+')) return '+$digits';
    if (digits.startsWith('82')) return '+$digits';
    if (digits.startsWith('0')) return '+82${digits.substring(1)}';
    return '+82$digits';
  }

  Future<void> _hydrateExisting() async {
    final user = client.auth.currentUser;
    if (user == null || !mounted) return;
    try {
      final row = await client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', user.id)
          .maybeSingle();
      final displayName = (row?['full_name'] ?? '').toString();
      final displayPhone = (row?['phone'] ?? user.phone ?? '').toString();
      await client.rpc(
        'customer_register_session',
        params: {'p_name': displayName},
      );
      if (!mounted) return;
      await context.read<AppState>().setAuthenticatedCustomer(
        displayName,
        displayPhone,
      );
    } catch (_) {
      // Session is still valid; analytics/profile sync can retry next launch.
    }
  }

  Future<void> _sendCode() async {
    final fullName = name.text.trim();
    final value = _normalizeKoreanPhone(phone.text);
    if (fullName.length < 2) {
      setState(() => error = 'Ism va familiyangizni kiriting.');
      return;
    }
    if (value.length < 10) {
      setState(() => error = 'Telefon raqamingizni to‘liq kiriting.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await client.auth.signInWithOtp(phone: value);
      if (!mounted) return;
      setState(() {
        normalizedPhone = value;
        codeSent = true;
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'SMS yuborilmadi: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _verify() async {
    final token = code.text.replaceAll(RegExp(r'\D'), '');
    if (token.length != 6) {
      setState(() => error = 'SMS orqali kelgan 6 xonali kodni kiriting.');
      return;
    }
    setState(() {
      verifying = true;
      error = null;
    });
    try {
      final response = await client.auth.verifyOTP(
        type: OtpType.sms,
        token: token,
        phone: normalizedPhone,
      );
      if (response.session == null) {
        throw const AuthException('Tasdiqlash yakunlanmadi.');
      }
      await client.rpc(
        'customer_register_session',
        params: {'p_name': name.text.trim()},
      );
      await context.read<AppState>().setAuthenticatedCustomer(
        name.text.trim(),
        normalizedPhone,
      );
      if (mounted) setState(() {});
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Kod tasdiqlanmadi: $e');
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!requirePhoneAuth || client.auth.currentSession != null) {
      return const StoreShell();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: MuhajeerLogoBadge(size: 92, radius: 24),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          codeSent
                              ? 'SMS kodni tasdiqlang'
                              : 'Muhajeer Books’ga kirish',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          codeSent
                              ? '$normalizedPhone raqamiga kelgan 6 xonali kodni kiriting.'
                              : 'Ismingiz va Koreya telefon raqamingiz kifoya. Parol kerak emas.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (!codeSent) ...[
                          TextField(
                            controller: name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Ism va familiya',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            onSubmitted: (_) => _sendCode(),
                            decoration: const InputDecoration(
                              labelText: 'Telefon raqam',
                              hintText: '010-1234-5678',
                              prefixIcon: Icon(Icons.phone_iphone_rounded),
                              helperText: '010 bilan yozsangiz, +82 avtomatik qo‘shiladi.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: sending ? null : _sendCode,
                            icon: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sms_outlined),
                            label: Text(
                              sending ? 'Yuborilmoqda...' : 'SMS kod yuborish',
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: code,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onSubmitted: (_) => _verify(),
                            decoration: const InputDecoration(
                              labelText: '6 xonali SMS kod',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: verifying ? null : _verify,
                            icon: verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              verifying ? 'Tekshirilmoqda...' : 'Kirish',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: sending
                                ? null
                                : () {
                                    setState(() {
                                      codeSent = false;
                                      code.clear();
                                      error = null;
                                    });
                                  },
                            child: const Text('Raqamni o‘zgartirish'),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFFCCD1),
                              ),
                            ),
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
