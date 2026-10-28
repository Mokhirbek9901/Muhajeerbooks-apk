import 'dart:async';
import 'package:flutter/material.dart';

/// Paint before touching storage/plugins/network, and keep failed launches visible.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key, required this.initialize, required this.app,
    this.timeout = const Duration(seconds: 20)});
  final Future<void> Function() initialize;
  final Widget app;
  final Duration timeout;
  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Future<void>? pending;
  bool ready = false, failed = false, busy = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }
  void start() {
    if (ready || busy) return;
    setState(() { busy = true; failed = false; });
    timer?.cancel();
    timer = Timer(widget.timeout, () {
      if (mounted && !ready) setState(() { failed = true; busy = false; });
    });
    // Retry observes an unfinished attempt instead of initializing SDKs twice.
    final task = pending ??= Future<void>.sync(widget.initialize);
    task.then((_) {
      timer?.cancel();
      if (mounted) setState(() { ready = true; busy = false; });
    }, onError: (Object error, StackTrace stack) {
      timer?.cancel();
      if (identical(pending, task)) pending = null;
      if (mounted) setState(() { failed = true; busy = false; });
    });
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ready ? widget.app : MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(backgroundColor: const Color(0xFFF7F3EA), body: SafeArea(
      child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.menu_book_rounded, size: 56, color: Color(0xFF075E55)),
          const SizedBox(height: 18),
          const Text('Muhajeer Books', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          if (!failed) const CircularProgressIndicator()
          else ...[
            const Text('Ilovani ochib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: busy ? null : start,
              icon: const Icon(Icons.refresh), label: const Text('Qayta urinish')),
          ],
        ],
      ))),
    )),
  );
}
