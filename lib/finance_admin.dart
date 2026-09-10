import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design_system.dart';

final _financeMoney = NumberFormat('#,###', 'en_US');
String _financeWon(num value) => '₩${_financeMoney.format(value.round())}';

class FinanceAdminPage extends StatefulWidget {
  const FinanceAdminPage({super.key, required this.secret});

  final String secret;

  @override
  State<FinanceAdminPage> createState() => _FinanceAdminPageState();
}

class _FinanceAdminPageState extends State<FinanceAdminPage> {
  final SupabaseClient client = Supabase.instance.client;
  Timer? timer;
  bool loading = true;
  String period = 'month';
  Map<String, dynamic> report = <String, dynamic>{};
  List<Map<String, dynamic>> expenses = <Map<String, dynamic>>[];

  static const periodLabels = <String, String>{
    'today': 'Bugun',
    'week': 'Shu hafta',
    'month': 'Shu oy',
    'all': 'Hammasi',
  };

  static const categoryLabels = <String, String>{
    'postage': 'Pochta',
    'packaging': 'Qadoqlash',
    'ads': 'Reklama',
    'transport': 'Transport',
    'other': 'Boshqa',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    timer = Timer.periodic(const Duration(seconds: 20), (_) => unawaited(_load(quiet: true)));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  int _int(String key) => (report[key] as num?)?.round() ?? 0;
  double _double(String key) => (report[key] as num?)?.toDouble() ?? 0;

  Future<void> _load({bool quiet = false}) async {
    if (!quiet && mounted) setState(() => loading = true);
    try {
      final result = await Future.wait<dynamic>([
        client.rpc('admin_finance_report', params: {
          'p_secret': widget.secret,
          'p_period': period,
        }),
        client.rpc('admin_finance_expenses', params: {
          'p_secret': widget.secret,
          'p_limit': 100,
        }),
      ]);
      final rawReport = result[0];
      final rawExpenses = result[1];
      if (!mounted) return;
      setState(() {
        report = rawReport is Map
            ? Map<String, dynamic>.from(rawReport)
            : <String, dynamic>{};
        expenses = rawExpenses is List
            ? rawExpenses
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      if (!quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moliya hisobotini yuklab bo‘lmadi: $e')),
        );
      }
    }
  }

  Future<void> _addExpense() async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var category = 'postage';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Xarajat qo‘shish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Xarajat turi'),
                items: categoryLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => category = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Summa (₩)',
                  hintText: 'Masalan: 12000',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Izoh (ixtiyoriy)',
                  hintText: 'Masalan: CJ pochta, 3 ta jo‘natma',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      amount.dispose();
      note.dispose();
      return;
    }

    final value = int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final noteText = note.text.trim();
    amount.dispose();
    note.dispose();
    if (value <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xarajat summasini to‘g‘ri kiriting.')),
        );
      }
      return;
    }

    try {
      await client.rpc('admin_add_finance_expense', params: {
        'p_secret': widget.secret,
        'p_amount': value,
        'p_category': category,
        'p_note': noteText,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xarajat saqlanmadi: $e')),
      );
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xarajatni o‘chirish'),
        content: Text(
          '${categoryLabels[expense['category']] ?? 'Xarajat'} — ${_financeWon((expense['amount'] as num?) ?? 0)} o‘chirilsinmi?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo‘q')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('O‘chirish')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await client.rpc('admin_delete_finance_expense', params: {
        'p_secret': widget.secret,
        'p_id': expense['id'],
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('O‘chirilmadi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final postageEstimated = report['postage_is_estimated'] == true;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Moliya va sof foyda', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text(
                      'Web, APK, Telegram va Instagram savdolari bitta server hisobotida.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _addExpense,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Xarajat'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: periodLabels.entries.map((entry) {
              return ChoiceChip(
                label: Text(entry.value),
                selected: period == entry.key,
                onSelected: (_) {
                  setState(() => period = entry.key);
                  unawaited(_load());
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1000 ? 3 : width >= 650 ? 2 : 1;
                final itemWidth = (width - (columns - 1) * 12) / columns;
                final cards = <Widget>[
                  _FinanceCard(title: 'Jami tushum', value: _financeWon(_int('total_revenue')), subtitle: 'Kitob + yetkazib berish', icon: Icons.payments_outlined),
                  _FinanceCard(title: 'Kitob tannarxi', value: _financeWon(_int('cost_of_goods')), subtitle: 'Sotilgan kitoblarning kelish narxi', icon: Icons.inventory_2_outlined),
                  _FinanceCard(title: 'Kitobdan foyda', value: _financeWon(_int('book_profit')), subtitle: 'Kitob savdosi − tannarx', icon: Icons.menu_book_rounded),
                  _FinanceCard(title: 'Pochta xarajati', value: _financeWon(_int('postage_expense')), subtitle: postageEstimated ? 'Hozircha taxmin: jo‘natma × ₩4,000' : 'Kiritilgan haqiqiy pochta xarajati', icon: Icons.local_shipping_outlined),
                  _FinanceCard(title: 'Boshqa chiqimlar', value: _financeWon(_int('other_expenses')), subtitle: 'Qadoqlash, reklama, transport va boshqa', icon: Icons.receipt_long_outlined),
                  _FinanceCard(title: 'SOF FOYDA', value: _financeWon(_int('net_profit')), subtitle: 'Marja ${_double('margin_percent').toStringAsFixed(1)}%', icon: Icons.trending_up_rounded, strong: true),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((card) => SizedBox(width: itemWidth, child: card)).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 10,
                  children: [
                    Text('📚 Sotilgan: ${_int('sold_books')} dona'),
                    Text('📦 Jo‘natilgan buyurtma: ${_int('shipped_orders')} ta'),
                    Text('📚 Kitob savdosi: ${_financeWon(_int('books_revenue'))}'),
                    Text('🚚 Yetkazish tushumi: ${_financeWon(_int('delivery_revenue'))}'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Text('Chiqimlar tarixi', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded), tooltip: 'Yangilash'),
            ],
          ),
          const SizedBox(height: 8),
          if (expenses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Hali qo‘lda kiritilgan xarajat yo‘q.'),
              ),
            )
          else
            ...expenses.map((e) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.remove_rounded)),
                    title: Text('${categoryLabels[e['category']] ?? 'Boshqa'} — ${_financeWon((e['amount'] as num?) ?? 0)}'),
                    subtitle: Text([
                      (e['expense_date'] ?? '').toString(),
                      if ((e['note'] ?? '').toString().trim().isNotEmpty) (e['note'] ?? '').toString(),
                      (e['source'] ?? '').toString() == 'telegram' ? 'Telegramdan kiritilgan' : 'Admin ilovadan kiritilgan',
                    ].join(' • ')),
                    trailing: IconButton(
                      onPressed: () => _deleteExpense(e),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'O‘chirish',
                    ),
                  ),
                )),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Hisob: Sof foyda = kitob savdosi + yetkazish tushumi − sotilgan kitoblar tannarxi − pochta − boshqa chiqimlar. Kitob sotib olish xarajatini yana alohida “boshqa chiqim”ga kiritmang — tannarxda allaqachon hisoblanadi.',
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.strong = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 23, child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: strong ? 23 : 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
