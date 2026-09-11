import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_ui.dart';
import 'app_state.dart';
import 'app_state_fixed.dart';
import 'app_update_gate.dart';
import 'auth_gate.dart';
import 'design_system.dart';
import 'navigation_sync.dart';
import 'store_ui.dart';

// Live Railway web va APK aynan shu bir xil storefront kodidan build qilinadi.
// Mijoz uchun majburiy Supabase login yo'q. Katalog cache'i tez start uchun
// saqlanadi, live baza esa AppState ichida fon rejimida yangilanadi.
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
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    // Eski admin/auth sessiyasi storefrontni bloklamasin, lekin tarmoqdagi
    // signOut javobini kutib app startini sekinlashtirmaymiz.
    if (Supabase.instance.client.auth.currentSession != null) {
      unawaited(
        Supabase.instance.client.auth.signOut().catchError((_) {}),
      );
    }
  }

  runApp(MuhajeerBooksApp(backendConfigured: backendConfigured));
}

class MuhajeerBooksApp extends StatelessWidget {
  MuhajeerBooksApp({super.key, required this.backendConfigured});

  final bool backendConfigured;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final MuhajeerNavigatorObserver _navigatorObserver =
      MuhajeerNavigatorObserver();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) =>
          AppStateFixed(backendConfigured: backendConfigured)..initialize(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        navigatorObservers: [_navigatorObserver],
        title: 'Muhajeer Books',
        debugShowCheckedModeBanner: false,
        theme: MuhajeerDesign.theme,
        builder: (context, child) => BrowserBackSync(
          navigatorKey: _navigatorKey,
          observer: _navigatorObserver,
          child: ColoredBox(
            color: AppColors.background,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: AppUpdateGate(
          child: kIsWeb && Uri.base.fragment.startsWith('admin_session=')
              ? const AdminGatePage()
              : (backendConfigured
                    ? const CustomerAuthGate()
                    : const StoreShell()),
        ),
      ),
    );
  }
}
