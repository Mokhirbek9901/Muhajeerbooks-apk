import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'customer_pin_page.dart';
import 'store_ui.dart' show CheckoutPage;
import 'preorder_partial_customer.dart';
import 'design_system.dart';
import 'uzbek_customer_style.dart';

/// A separate prepaid-order checkout: no duplicate normal order is created.
/// The original deposit is credited exactly once on the backend.
class CustomerPreorderBalancesPage extends StatefulWidget {
  const CustomerPreorderBalancesPage({super.key, this.focusPreorderId});
  final String? focusPreorderId;

  @override
  State<CustomerPreorderBalancesPage> createState() =>
      _CustomerPreorderBalancesPageState();
}

class _CustomerPreorderBalancesPageState
    extends State<CustomerPreorderBalancesPage> {
  Future<List<Map<String, dynamic>>>? future;
  bool busy = false;
  final picker = ImagePicker();
  final money = NumberFormat('#,##0', 'en_US');
  String won(int amount) => '₩${money.format(amount)}';

  Future<List<Map<String, dynamic>>> loadAll() async {
    final state = context.read<AppState>();
    if (state.backendConfigured && !state.checkoutIdentityReady)
      return const [];
    final rows = await state.releasePreorders();
    // Read-only summary lookup for multi-title web requests. Failed lookups
    // cannot hide any preorder or change ordinary checkout flows.
    final multi = rows.where((row) =>
      row['source'] == 'web' &&
      row['request_items'] is List &&
      (row['request_items'] as List).length > 1).take(12);
    await Future.wait(multi.map((row) async {
      try {
        final info = await state.webPreorderPartial((row['id'] ?? '').toString(), 'detail');
        final batches = (info['batches'] as List? ?? const [])
            .whereType<Map>().where((v) => v['status'] != 'cancelled').toList();
        if (batches.isEmpty) return;
        var arrived = 0;
        for (final batch in batches) {
          for (final item in (batch['items'] as List? ?? const [])) {
            if (item is Map) arrived += (item['quantity'] as num?)?.toInt() ?? 0;
          }
        }
        var requested = 0;
        for (final item in (info['original_items'] as List? ?? const [])) {
          if (item is Map) requested += (item['quantity'] as num?)?.toInt() ?? 0;
        }
        row['_partial_active'] = true;
        row['_partial_arrived'] = arrived;
        row['_partial_missing'] = (requested - arrived).clamp(0, 100000).toInt();
        final current = batches.last;
        row['_partial_payment_ready'] = current['status'] != 'prepared';
        row['_partial_due'] = (current['amount_due'] as num?)?.toInt() ?? 0;
      } catch (_) {
        // A temporary partial-status failure does not affect order visibility.
      }
    }));
    rows.sort((a, b) {
      final target = widget.focusPreorderId;
      if (target != null) {
        if ('${a['id']}' == target && '${b['id']}' != target) return -1;
        if ('${b['id']}' == target && '${a['id']}' != target) return 1;
      }
      final aa =
          DateTime.tryParse('${a['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bb =
          DateTime.tryParse('${b['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bb.compareTo(aa);
    });
    return rows;
  }

  @override
  void initState() {
    super.initState();
    future = loadAll();
  }

  Future<void> refresh() async {
    final next = loadAll();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> extra(int preorderId, String bookId, int delta) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>().changePreorderExtra(
        preorderId,
        bookId,
        delta,
      );
      await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Kitob qo‘shilmadi: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseBook(int preorderId, String originalBookId) async {
    final available = context
        .read<AppState>()
        .books
        .where(
          (b) =>
              b.isActive &&
              b.stock > 0 &&
              b.id != originalBookId &&
              b.price > 0,
        )
        .toList();
    Book? chosen;
    var query = '';
    chosen = await showModalBottomSheet<Book>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) {
          final visible = available
              .where((b) => b.title.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                MediaQuery.viewInsetsOf(sheet).bottom + 12,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheet).height * .67,
                child: Column(
                  children: [
                    const Text(
                      'Qo‘shimcha kitob tanlash',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) => update(() => query = value),
                      decoration: const InputDecoration(
                        labelText: 'Kitob qidirish',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Text('Sotuvdagi kitob topilmadi'),
                            )
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (_, i) {
                                final b = visible[i];
                                return ListTile(
                                  leading: const Icon(Icons.menu_book_outlined),
                                  title: Text(b.title, maxLines: 2),
                                  subtitle: Text(
                                    '${won(b.price)} • ${b.stock} ta mavjud',
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                  onTap: () => Navigator.pop(sheet, b),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (chosen == null || !mounted) return;
    await extra(preorderId, chosen.id, 1);
  }

  Future<void> submitProof(int preorderId, int amount) async {
    if (busy || amount <= 0) return;
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1600,
      maxHeight: 2400,
    );
    if (file == null || !mounted) return;
    final agree = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Qolgan to‘lov cheki'),
        content: Text(
          'Bankka ${won(amount)} o‘tkazganingizni tekshiring. '
          'Avans bu summadan allaqachon ayrilgan. '
          'Rasmni yuborgandan keyin savatni o‘zgartirib bo‘lmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Qaytish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chekni yuborish'),
          ),
        ],
      ),
    );
    if (agree != true || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>().submitPreorderRemainingPayment(
        preorderId,
        file,
      );
      await refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chek yuborildi. Admin tekshiradi ✅')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Chek yuborilmadi: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(
      title: const Text('Oldindan zakazlarim'),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          icon: const Icon(Icons.refresh),
          onPressed: refresh,
        ),
      ],
    ),
    body:
        context.watch<AppState>().backendConfigured &&
            !context.watch<AppState>().checkoutIdentityReady
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 52),
                  const SizedBox(height: 14),
                  const Text(
                    'Zakazlarni ko‘rish uchun profilga kiring',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ism va telefoningizni saqlang. Boshqa telefondagi '
                    'buyurtmalarni do‘kon orqali xavfsiz tiklash mumkin.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const CustomerPinPage(),
                        ),
                      );
                      if (mounted &&
                          context.read<AppState>().checkoutIdentityReady) {
                        await refresh();
                      }
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Kirish'),
                  ),
                ],
              ),
            ),
          )
        : FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snap) {
              if (snap.hasError)
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Zakazlarni yuklab bo‘lmadi: ${snap.error}'),
                  ),
                );
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              final rows = snap.data!;
              if (rows.isEmpty)
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bu qurilmada zakaz topilmadi. Boshqa telefondagi buyurtmalarni tiklash uchun Mening ma’lumotlarim bo‘limidan so‘rov yuboring.',
                    ),
                  ),
                );
              return RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 45),
                  children: [
                    if (busy) const LinearProgressIndicator(),
                    for (final row in rows) _invoiceCard(row),
                  ],
                ),
              );
            },
          ),
  );

  Future<void> _openWebCheckout(Map<String, dynamic> record) async {
    final state = context.read<AppState>();
    if (!state.pinSessionActive) {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          settings: const RouteSettings(name: 'mb:web-preorder-pin'),
          builder: (_) => const CustomerPinPage(),
        ),
      );
      if (!mounted || !context.read<AppState>().pinSessionActive) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'mb:web-preorder-to-real-checkout'),
        builder: (_) =>
            CheckoutPage(preorderId: (record['id'] ?? '').toString()),
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> _openPreorder(Map<String, dynamic> record) async {
    final isWeb = record['source'] == 'web';
    final id = (record['id'] ?? '').toString();
    if (isWeb) {
      try {
        // Check authoritative server partial batches before opening
        // old full-order checkout (which must never charge those batches).
        final d = await context.read<AppState>().webPreorderPartial(id, 'detail');
        if (!mounted) return;
        final rows = (d['batches'] as List? ?? const []);
        final partial = rows.whereType<Map>().any((b) => b['status'] != 'cancelled');
        if (partial) {
          await Navigator.push<void>(context,
            MaterialPageRoute(builder: (_) =>
              CustomerPartialPreorderPage(preorderId: id)));
          if (mounted) await refresh();
          return;
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Oldindan zakaz ochilmadi: ' + e.toString())));
        return;
      }
    }
    if (!mounted) return;
    final ref = isWeb ? id : 'native:' + id;
    await Navigator.push<void>(context,
      MaterialPageRoute(builder: (_) => CheckoutPage(preorderId: ref)));
    if (mounted) await refresh();
  }

  Widget _invoiceCard(Map<String, dynamic> record) {
    final status = '${record['status'] ?? ''}';
    final isContactOnly = record['ownership'] == 'contact';
    final isWeb = record['source'] == 'web';
    final isPartial = record['_partial_active'] == true;

    return Card(
      child: ListTile(
        title: Text('${record['title'] ?? record['book_title'] ?? 'Kitob'}'),
        subtitle: Text(
          '${isWeb ? 'Web oldindan zakaz\n' : ''}'
          'Holat: ${isPartial ? 'Qisman keldi' : (status == 'arrived' ? 'Kitob keldi' : status)}\n'
          '${isPartial ? 'Keldi: ${record['_partial_arrived']} ta · Kelmagan: ${record['_partial_missing']} ta\n' : ''}'
          'Avans: ${won((record['deposit_credit'] as num?)?.toInt() ?? 0)}'
          '\nQolgan to‘lov: ${isPartial && record['_partial_payment_ready'] != true ? 'Manzil tanlangach hisoblanadi' : won(isPartial ? ((record['_partial_due'] as num?)?.toInt() ?? 0) : ((record['amount_due'] as num?)?.toInt() ?? 0))}'
          '\nQaytariladigan pul: ${won((record['refund_due'] as num?)?.toInt() ?? 0)}'
          '${isContactOnly ? '\nBu zakaz profil ma’lumotlari bilan topildi. To‘lovni davom ettirish uchun asl qurilmada oching yoki admin bilan bog‘laning.' : ''}',
        ),
        isThreeLine: true,
        trailing: isContactOnly
            ? const Icon(Icons.lock_outline)
            : const Icon(Icons.chevron_right),
        onTap: isContactOnly ? null : () => _openPreorder(record),
      ),
    );
  }
}
