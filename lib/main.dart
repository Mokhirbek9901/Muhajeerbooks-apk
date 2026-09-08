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
        builder: (context, child) => _ProfessionalAppFrame(
          child: child ?? const SizedBox.shrink(),
        ),
        home: backendConfigured ? const CustomerAuthGate() : const StoreShell(),
      ),
    );
  }
}

class _ProfessionalAppFrame extends StatelessWidget {
  const _ProfessionalAppFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.navy,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: ColoredBox(
          color: AppColors.background,
          child: Column(
            children: [
              const _OwnerBrandBar(),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerBrandBar extends StatelessWidget {
  const _OwnerBrandBar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Mohirbek Ismoilov — Muhajeer Books',
      child: Container(
        height: 42,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: AppColors.navy,
          boxShadow: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_rounded,
              size: 17,
              color: AppColors.gold,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Mohirbek Ismoilov',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x17FFFFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 14,
                    color: AppColors.gold,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Muhajeer Books',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
