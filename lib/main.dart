import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'app_state_fixed.dart';
import 'auth_gate.dart';
import 'design_system.dart';
import 'store_ui.dart';

// Live Railway web va APK aynan shu bir xil storefront kodidan build qilinadi.
// Customer logout local ma'lumotlarni darhol tozalaydi.
// Admin fon yangilanishi jim ishlaydi; mijoz buyurtma holatini ilova ichida ko'radi.
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
  final backendConfigured =
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  if (backendConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
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
