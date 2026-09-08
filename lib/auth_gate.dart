import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'admin_ui.dart';
import 'customer_identity.dart';
import 'brand.dart';
import 'design_system.dart';
import 'store_ui.dart';

/// Production customers verify their phone once; Supabase restores the session.
const bool requirePhoneAuth = bool.fromEnvironment(
  'REQUIRE_PHONE_AUTH',
  defaultValue: true,
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
  String? readyUserId;
  bool syncing = false;
  Timer? resendTimer;
  DateTime? resendAt;
  int get resendSeconds => resendAt == null
      ? 0
      : (resendAt!.difference(DateTime.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 60);

  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSub = client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (event.session == null) {
        setState(() {
          readyUserId = null;
          codeSent = false;
          name.clear();
          phone.clear();
          code.clear();
          normalizedPhone = '';
          error = null;
        });
      } else if (!verifying &&
          !syncing &&
          readyUserId != event.session!.user.id) {
        unawaited(_hydrateExisting());
      }
    });
    if (client.auth.currentSession != null) {
      syncing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateExisting());
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    resendTimer?.cancel();
    name.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _hydrateExisting({String? enteredName}) async {
    final user = client.auth.currentUser;
    if (user == null || !mounted) return;
    if ((user.phone ?? '').isEmpty || user.phoneConfirmedAt == null) {
      setState(() => syncing = false);
      return;
    }
    final state = context.read<AppState>();
    setState(() {
      syncing = true;
      error = null;
    });
    try {
      await state.initialize();
      final result = await client.rpc(
        'customer_register_session',
        params: {'p_name': enteredName ?? ''},
      );
      if (!mounted || client.auth.currentUser?.id != user.id) return;
      final profile = Map<String, dynamic>.from(result as Map);
      await state.setAuthenticatedCustomer(
        (profile['full_name'] ?? enteredName ?? '').toString(),
        user.phone!,
      );
      if (!mounted || client.auth.currentUser?.id != user.id) return;
      setState(() => readyUserId = user.id);
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Hisobni yuklab bo‘lmadi. Internetni tekshirib, qayta urining.',
        );
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  void _startResendTimer() {
    resendAt = DateTime.now().add(const Duration(seconds: 60));
    resendTimer?.cancel();
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (resendSeconds == 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (sending || verifying || resendSeconds > 0) return;
    final fullName = name.text.trim();
    final value = normalizeCustomerPhone(phone.text);
    if (fullName.length < 2) {
      setState(() => error = 'Ismingizni kiriting.');
      return;
    }
    if (value == null) {
      setState(() => error = 'Telefon raqamingizni to‘liq kiriting.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await client.auth.signInWithOtp(
        phone: value,
        data: {'full_name': fullName},
      );
      if (!mounted) return;
      setState(() {
        normalizedPhone = value;
        codeSent = true;
        code.clear();
        _startResendTimer();
      });
    } on AuthException catch (_) {
      if (mounted)
        setState(
          () => error = 'SMS yuborilmadi. Raqamni tekshiring va birozdan keyin qayta urining.',
        );
    } catch (_) {
      if (mounted) setState(() => error = 'Internet aloqasini tekshiring.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _verify() async {
    if (verifying || sending || !codeSent) return;
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
      await _hydrateExisting(enteredName: name.text.trim());
    } on AuthException catch (_) {
      if (mounted)
        setState(
          () => error = 'Kod noto‘g‘ri yoki muddati tugagan. Qayta tekshiring.',
        );
    } catch (_) {
      if (mounted) setState(() => error = 'Internet aloqasini tekshiring.');
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!requirePhoneAuth ||
        (readyUserId != null && readyUserId == client.auth.currentUser?.id)) {
      return const StoreShell();
    }

    if (syncing ||
        (client.auth.currentUser?.phoneConfirmedAt != null &&
            client.auth.currentSession != null &&
            !verifying)) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (syncing)
                    const CircularProgressIndicator()
                  else ...[
                    Text(
                      error ?? 'Hisobni yuklash kerak.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _hydrateExisting(
                        enteredName: name.text.trim().isEmpty
                            ? null
                            : name.text.trim(),
                      ),
                      child: const Text('Qayta urinish'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final state = context.read<AppState>();
                        try {
                          await client.auth.signOut();
                          await state.clearCustomerSession();
                        } catch (_) {
                          if (mounted)
                            setState(
                              () => error = 'Chiqib bo‘lmadi. Qayta urining.',
                            );
                        }
                      },
                      child: const Text('Boshqa raqam bilan kirish'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
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
                              : 'Ismingiz va telefon raqamingiz kifoya. Parol kerak emas.',
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
                            enabled: !sending,
                            maxLength: 60,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Ismingiz',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phone,
                            enabled: !sending,
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
                            onPressed: sending || resendSeconds > 0
                                ? null
                                : _sendCode,
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
                              sending
                                  ? 'Yuborilmoqda...'
                                  : resendSeconds > 0
                                  ? 'Qayta yuborish: ${resendSeconds}s'
                                  : 'SMS kod yuborish',
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
                          TextButton.icon(
                            onPressed: sending || verifying || resendSeconds > 0
                                ? null
                                : _sendCode,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              resendSeconds > 0
                                  ? 'Qayta yuborish: ${resendSeconds}s'
                                  : 'Kodni qayta yuborish',
                            ),
                          ),
                          TextButton(
                            onPressed: sending || verifying
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
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: sending || verifying
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminGatePage(),
                                  ),
                                ),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text('Admin kirishi'),
                        ),
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
