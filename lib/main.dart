import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'app_state_fixed.dart';
import 'auth_gate.dart';
import 'design_system.dart';
import 'store_ui.dart';

// Live Railway web va APK aynan shu bir xil storefront kodidan build qilinadi.
// Mijoz uchun majburiy Supabase login yo'q; eski sessiya katalog/admin RPC'larini
// buzmasligi uchun startupda tozalanadi.
// 2026-09-09: 10-rasmli kitob galereyasi va same-origin web backend buildi.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rytfhjvhjxnbhgitowho.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ5dGZoanZoanhuYmhnaXRvd2hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2MzIzNjMsImV4cCI6MjEwNDIwODM2M30.JYcxkDTJ0ChS34Id_6UI-vxPXjKnWc5rTjH0IampVjs',
  );
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
        home: backendConfigured ? const CustomerAuthGate() : const StoreShell(),
      ),
    );
  }
}
