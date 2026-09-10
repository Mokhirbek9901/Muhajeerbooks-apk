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
// 2026-09-11: Android APK doim Muhajeer Books'ning live Supabase loyihasiga
// ulanadi. GitHub build secret eski/bo'sh bo'lsa ham APK offline eski seedga
// tushmaydi. Web esa o'z originidagi /supabase proxy orqali ishlaydi.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const definedSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const liveSupabaseUrl = 'https://rytfhjvhjxnbhgitowho.supabase.co';
  const liveSupabasePublishableKey =
      'sb_publishable_5lDr_sw4bu8g3x8LCVzp4g_sHSTMBiO';

  final supabaseUrl = kIsWeb
      ? '${Uri.base.origin}/supabase'
      : liveSupabaseUrl;
  final supabaseAnonKey = kIsWeb && definedSupabaseAnonKey.trim().isNotEmpty
      ? definedSupabaseAnonKey.trim()
      : liveSupabasePublishableKey;

  final backendConfigured =
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  if (backendConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
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
