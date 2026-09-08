import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'brand.dart';
import 'design_system.dart';
import 'store_ui.dart';

class CustomerAuthGate extends StatefulWidget {
  const CustomerAuthGate({super.key});

  @override
  State<CustomerAuthGate> createState() => _CustomerAuthGateState();
}

class _CustomerAuthGateState extends State<CustomerAuthGate> {
  final name = TextEditingController();
  final phone = TextEditingController();

  bool saving = false;
  bool syncScheduled = false;
  String? error;

  SupabaseClient get client => Supabase.instance.client;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  String? _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);

    // O‘zbekiston: +998 XX XXX XX XX, 998XXXXXXXXX yoki mahalliy 9 raqam.
    if (digits.length == 12 && digits.startsWith('998')) {
      return '+$digits';
    }
    if (digits.length == 9 && !digits.startsWith('0')) {
      return '+998$digits';
    }

    // Koreya: 010-XXXX-XXXX yoki +82 10-XXXX-XXXX.
    if (digits.length == 11 && digits.startsWith('010')) {
      return '+82${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('8210')) {
      return '+$digits';
    }

    return null;
  }

  bool _isValidSavedCustomer(Map<String, String> customer) {
    final savedName = (customer['name'] ?? '').trim();
    final savedPhone = (customer['phone'] ?? '').trim();
    return savedName.length >= 2 && _normalizePhone(savedPhone) != null;
  }

  void _syncSavedCustomer(AppState state) {
    if (syncScheduled || !state.isOnlineBackend) return;
    syncScheduled = true;
    final savedName = (state.savedCustomer['name'] ?? '').trim();
    final savedPhone = (state.savedCustomer['phone'] ?? '').trim();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await client.rpc(
          'customer_register_free',
          params: {'p_name': savedName, 'p_phone': savedPhone},
        );
      } catch (_) {
        // Xarid qilish internetdagi vaqtinchalik xatolik sabab bloklanmaydi.
        // Keyingi ilova ochilishida profil yana sinxronlanadi.
      }
    });
  }

  Future<void> _continue() async {
    final fullName = name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final rawPhone = phone.text.trim();
    final phoneValue = _normalizePhone(rawPhone);

    if (fullName.length < 2) {
      setState(() => error = 'Ismingizni kiriting.');
      return;
    }
    if (phoneValue == null) {
      setState(
        () => error = 'O‘zbekiston (+998) yoki Koreya (010 / +82) telefon raqamini to‘liq kiriting.',
      );
      return;
    }

    setState(() {
      saving = true;
      error = null;
      syncScheduled = true;
    });

    final state = context.read<AppState>();
    try {
      // Avval qurilmaga saqlaymiz: profil bepul va SMSsiz ishlaydi.
      await state.setAuthenticatedCustomer(fullName, phoneValue);

      // Admin paneldagi mijozlar statistikasi uchun serverga ham yozamiz.
      if (state.isOnlineBackend) {
        try {
          await client.rpc(
            'customer_register_free',
            params: {'p_name': fullName, 'p_phone': phoneValue},
          );
        } catch (_) {
          // Mahalliy profil saqlangan. Internet qaytgach keyingi ochilishda sync bo‘ladi.
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Ma’lumotni saqlab bo‘lmadi. Qayta urinib ko‘ring.';
          syncScheduled = false;
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loading) {
      return const _CustomerLoadingScreen();
    }

    if (_isValidSavedCustomer(state.savedCustomer)) {
      _syncSavedCustomer(state);
      return const StoreShell();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      color: AppColors.navy,
                      child: const Column(
                        children: [
                          MuhajeerLogoBadge(size: 88, radius: 24),
                          SizedBox(height: 15),
                          Text(
                            'Muhajeer Books’ga\nxush kelibsiz',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.35,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Bepul profil • parol ham, SMS ham kerak emas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFE5EDF5),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _WelcomeFeatureRow(),
                            const SizedBox(height: 19),
                            TextField(
                              controller: name,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Ismingiz',
                                hintText: 'Masalan: Azizbek',
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
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-\s()]'),
                                ),
                                LengthLimitingTextInputFormatter(24),
                              ],
                              onSubmitted: (_) => saving ? null : _continue(),
                              decoration: const InputDecoration(
                                labelText: 'Telefon raqamingiz',
                                hintText:
                                    '+998 90 123 45 67 yoki 010-1234-5678',
                                prefixIcon: Icon(Icons.phone_iphone_rounded),
                                helperText: 'O‘zbekiston +998 va Koreya 010 / +82 raqamlari qabul qilinadi.',
                              ),
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
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 19,
                                      color: AppColors.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        error!,
                                        style: const TextStyle(
                                          color: AppColors.danger,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 17),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: saving ? null : _continue,
                                icon: saving
                                    ? const SizedBox(
                                        width: 19,
                                        height: 19,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward_rounded),
                                label: Text(
                                  saving ? 'Saqlanmoqda...' : 'Davom etish',
                                ),
                              ),
                            ),
                            const SizedBox(height: 13),
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                  color: AppColors.muted,
                                ),
                                SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Ism va telefon buyurtmalarni rasmiylashtirish va siz bilan bog‘lanish uchun saqlanadi.',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

class _WelcomeFeatureRow extends StatelessWidget {
  const _WelcomeFeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _WelcomeFeature(
          icon: Icons.check_circle_outline_rounded,
          text: 'Bepul',
        ),
        _WelcomeFeature(icon: Icons.sms_outlined, text: 'SMS shart emas'),
        _WelcomeFeature(
          icon: Icons.speed_rounded,
          text: 'Bir marta kiritiladi',
        ),
      ],
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.success),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
      ],
    ),
  );
}

class _CustomerLoadingScreen extends StatelessWidget {
  const _CustomerLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MuhajeerLogoBadge(size: 82, radius: 22),
            SizedBox(height: 18),
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 12),
            Text(
              'Muhajeer Books',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
