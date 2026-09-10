import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'app_state_fixed.dart';
import 'app_update_gate.dart';
import 'admin_ui.dart';
import 'auth_gate.dart';
import 'design_system.dart';
import 'store_ui.dart';

// Live Railway web va APK aynan shu bir xil storefront kodidan build qilinadi.
// Mijoz uchun majburiy Supabase login yo'q; eski sessiya katalog/admin RPC'larini
// buzmasligi uchun startupda tozalanadi.
// 2026-09-09: Supabase legacy anon JWT o'rniga aktiv publishable key ishlatiladi.
// 2026-09-09: yangi o'zbekona UI uchun web va APK buildini bir xil manbadan yangilash.
// 2026-09-10: rasm yuklash ishonchliligi tuzatmasini web va APKga bir xil build qilish.
// 2026-09-11: Android APK yangi release chiqsa ilova ichida yangilash oynasini ko'rsatadi.
// 2026-09-11: bo'sh GitHub build secret APKni offline eski katalogga tushirmasligi uchun
// live Supabase URL/publishable key xavfsiz fallback sifatida ishlatiladi.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const definedSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const defaultSupabaseUrl = 'https://rytfhjvhjxnbhgitowho.supabase.co';
  const defaultSupabaseAnonKey =
      'sb_publishable_5lDr_sw4bu8g3x8LCVzp4g_sHSTMBiO';

  final supabaseUrl = definedSupabaseUrl.trim().isEmpty
      ? defaultSupabaseUrl
      : definedSupabaseUrl.trim();
  final supabaseAnonKey = definedSupabaseAnonKey.trim().isEmpty
      ? defaultSupabaseAnonKey
      : definedSupabaseAnonKey.trim();

  final effectiveSupabaseUrl = kIsWeb
      ? '${Uri.base.origin}/supabase'
      : supabaseUrl;
  final backendConfigured =
      effectiveSupabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  if (backendConfigured) {
    await Supabase.initialize(
      url: effectiveSupabaseUrl,
      anonKey: supabaseAnonKey,
    );
    // Ilgari SMS/login bo'lgan davrdan brauzerda qolgan sessiya eskirgan bo'lsa,
    // Supabase so'rovlariga noto'g'ri JWT qo'shib katalog va admin tekshiruvini
    // buzishi mumkin. Hozir customer login ishlatilmaydi, shuning uchun xavfsiz
    // tarzda eski sessiyani startupda olib tashlaymiz.
    try {
      if (Supabase.instance.client.auth.currentSession != null) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {
      // Sessiya tozalashdagi vaqtinchalik tarmoq xatosi do'konni bloklamasin.
    }
  }

  runApp(MuhajeerBooksApp(backendConfigured: backendConfigured));
}

class MuhajeerBooksApp extends StatelessWidget {
  const MuhajeerBooksApp({super.key, required this.backendConfigured});

  final bool backendConfigured;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) =>
          AppStateFixed(backendConfigured: backendConfigured)..initialize(),
      child: MaterialApp(
        title: 'Muhajeer Books',
        debugShowCheckedModeBanner: false,
        theme: MuhajeerDesign.theme,
        builder: (context, child) => ColoredBox(
          color: AppColors.background,
          child: child ?? const SizedBox.shrink(),
        ),
        home: AppUpdateGate(
          child: kIsWeb && Uri.base.fragment.startsWith('admin_session=')
              ? const AdminGatePage()
              : (backendConfigured ? const CustomerAuthGate() : const StoreShell()),
        ),
      ),
    );
  }
}
