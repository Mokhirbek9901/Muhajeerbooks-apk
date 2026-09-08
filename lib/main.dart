import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'auth_gate.dart';
import 'design_system.dart';
import 'store_ui.dart';

// Production web deploy marker: keeps Railway synced with the latest main branch.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rytfhjvhjxnbhgitowho.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXAiLCJyZWYiOiJyeXRmaGp2aGp4bmJoZ2l0b3dobyIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzg4NjMyMzYzLCJleHAiOjIxMDQyMDgzNjN9.JYcxkDTJ0ChS34Id_6UI-vxPXjKnWc5rTjH0IampVjs',
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
    return ChangeNotifierProvider(
      create: (_) =>
          AppState(backendConfigured: backendConfigured)..initialize(),
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
