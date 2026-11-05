import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design_system.dart';

typedef PreorderWaiterCountLoader = Future<int> Function(String bookId);

/// The public RPC returns only an aggregate of distinct active customers.
/// No contact details, advance payments or private preorder rows are sent
/// to the storefront.
Future<int> loadPreorderWaiterCount(String bookId) async {
  final result = await Supabase.instance.client.rpc(
    'book_preorder_waiter_count',
    params: {'p_book_id': bookId},
  ).timeout(const Duration(seconds: 15));
  if (result is num && result >= 0 && result == result.roundToDouble()) {
    return result.toInt();
  }
  throw const FormatException('Kutayotganlar soni noto‘g‘ri qaytdi.');
}

class BookPreorderWaiterCount extends StatefulWidget {
  const BookPreorderWaiterCount({
    super.key,
    required this.bookId,
    this.loader,
  });

  final String bookId;
  final PreorderWaiterCountLoader? loader;

  @override
  State<BookPreorderWaiterCount> createState() =>
      _BookPreorderWaiterCountState();
}

class _BookPreorderWaiterCountState extends State<BookPreorderWaiterCount> {
  late Future<int> _request;

  void _reload() {
    _request = Future.sync(
      () => (widget.loader ?? loadPreorderWaiterCount)(widget.bookId),
    );
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant BookPreorderWaiterCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId || oldWidget.loader != widget.loader) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: _request,
    builder: (context, snapshot) {
      final ready = snapshot.connectionState == ConnectionState.done;
      final failed = ready && (snapshot.hasError || !snapshot.hasData);
      final count = ready && !failed ? snapshot.data! : null;
      final label = !ready
          ? 'Kutayotganlar soni yuklanmoqda…'
          : failed
              ? 'Kutayotganlar sonini yangilash'
              : '$count kishi kutyapti';
      return OutlinedButton.icon(
        key: const ValueKey('book-preorder-waiter-count'),
        onPressed: ready ? () => setState(_reload) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF176657),
          backgroundColor: const Color(0xFFE8F4ED),
          disabledForegroundColor: AppColors.muted,
          side: const BorderSide(color: Color(0xFFB8DCD0)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          failed ? Icons.refresh_rounded : Icons.people_alt_outlined,
          size: 18,
        ),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      );
    },
  );
}
