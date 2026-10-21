import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design_system.dart';

class BookPurchaseCount {
  const BookPurchaseCount(this.recorded, this.historical);
  final int recorded, historical;
  int get total => recorded + historical;

  factory BookPurchaseCount.fromJson(dynamic value) {
    if (value is! Map) throw const FormatException('Missing purchase count');
    final recorded = value['recorded_count'];
    final historical = value['historical_count'];
    if (recorded is! int || historical is! int || recorded < 0 || historical < 0) {
      throw const FormatException('Invalid purchase count');
    }
    return BookPurchaseCount(recorded, historical);
  }
}

typedef BookPurchaseCountLoader = Future<BookPurchaseCount> Function(String);

Future<BookPurchaseCount> loadBookPurchaseCount(String bookId) async {
  final data = await Supabase.instance.client.rpc(
    'web_book_purchase_count',
    params: {'p_book_id': bookId},
  ).timeout(const Duration(seconds: 15));
  return BookPurchaseCount.fromJson(data);
}

/// Mounted only by the web storefront. Fetches once per opened book, never
/// loads private order rows into the client, and never treats a failure as zero.
class WebBookPurchaseCount extends StatefulWidget {
  const WebBookPurchaseCount({super.key, required this.bookId, this.loader});
  final String bookId;
  final BookPurchaseCountLoader? loader;

  @override
  State<WebBookPurchaseCount> createState() => _WebBookPurchaseCountState();
}

class _WebBookPurchaseCountState extends State<WebBookPurchaseCount> {
  late Future<BookPurchaseCount> _request;

  void _load() {
    // Future.sync also turns a missing backend initialization into retry UI.
    _request = Future.sync(
      () => (widget.loader ?? loadBookPurchaseCount)(widget.bookId),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WebBookPurchaseCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId || oldWidget.loader != widget.loader) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BookPurchaseCount>(
    future: _request,
    builder: (context, snapshot) {
      final ready = snapshot.connectionState == ConnectionState.done;
      final failed = ready && (snapshot.hasError || !snapshot.hasData);
      final count = ready && !failed ? snapshot.data : null;
      final amount = count == null ? '' : NumberFormat.decimalPattern('en_US').format(count.total);
      return OutlinedButton.icon(
        key: const ValueKey('book-purchase-count'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF176657),
          backgroundColor: const Color(0xFFE8F4ED),
          disabledForegroundColor: AppColors.muted,
          side: const BorderSide(color: Color(0xFFB8DCD0)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: Icon(failed ? Icons.refresh_rounded : Icons.shopping_bag_outlined, size: 20),
        label: Text(
          !ready ? 'Xaridlar soni yuklanmoqda…' : failed
              ? 'Xaridlar sonini qayta yuklash'
              : '$amount dona xarid qilingan',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        onPressed: !ready ? null : failed
            ? () => setState(_load)
            : () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Shu kungacha xarid qilingan'),
                  content: Text(
                    '$amount dona\n\n'
                    'Tasdiqlangan buyurtmalardagi sotilgan kitob nusxalari hisoblanadi. '
                    'Bir buyurtmada 2 dona olingan bo‘lsa, 2 dona hisoblanadi. '
                    'Bekor qilingan va tasdiqlanmagan buyurtmalar kiritilmaydi.'
                    '${count!.historical > 0 ? '\n\nShundan ${count.historical} dona avvalgi sotuv tarixidan.' : ''}',
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Yopish'))],
                ),
              ),
      );
    },
  );
}
