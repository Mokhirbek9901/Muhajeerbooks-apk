import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'store_ui.dart';

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
    return ChangeNotifierProvider(
      create: (_) =>
          AppState(backendConfigured: backendConfigured)..initialize(),
      child: MaterialApp(
        title: 'Muhajeer Books',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: const Color(0xFFFF8A00),
                brightness: Brightness.light,
              ).copyWith(
                primary: const Color(0xFF10213D),
                onPrimary: Colors.white,
                secondary: const Color(0xFFFF8A00),
                tertiary: const Color(0xFFFFC928),
              ),
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF7F8FA),
            foregroundColor: Color(0xFF10213D),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: TextStyle(
              color: Color(0xFF10213D),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10213D),
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: Color(0xFFFFE1C8),
            elevation: 0,
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          cardTheme: CardThemeData(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE8EAED)),
            ),
          ),
        ),
        home: const StoreShell(),
      ),
    );
  }
}
