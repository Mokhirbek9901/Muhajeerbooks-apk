import 'package:flutter/material.dart';
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
  bool syncScheduled = false;

  SupabaseClient get client => Supabase.instance.client;

  String? _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);

    if (digits.length == 12 && digits.startsWith('998')) {
      return '+$digits';
    }
    if (digits.length == 9 && !digits.startsWith('0')) {
      return '+998$digits';
    }
    if (digits.length == 11 && digits.startsWith('010')) {
      return '+82${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('8210')) {
      return '+$digits';
    }
    return null;
  }

  bool _hasSavedCustomer(Map<String, String> customer) {
    final savedName = (customer['name'] ?? '').trim();
    final savedPhone = (customer['phone'] ?? '').trim();
    return savedName.length >= 2 && _normalizePhone(savedPhone) != null;
  }

  void _syncSavedCustomer(AppState state) {
    if (syncScheduled || !state.isOnlineBackend) return;
    if (!_hasSavedCustomer(state.savedCustomer)) return;

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
        // Xarid jarayoni serverdagi vaqtinchalik xatolik sabab bloklanmaydi.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loading) {
      return const _CustomerLoadingScreen();
    }

    _syncSavedCustomer(state);

    // Majburiy login yo‘q. Mijoz do‘konni darhol ko‘radi.
    // Ism, telefon va manzil buyurtma paytida saqlanadi va keyingi safar
    // shu qurilma/brauzerda avtomatik to‘ldiriladi.
    return const StoreShell();
  }
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
