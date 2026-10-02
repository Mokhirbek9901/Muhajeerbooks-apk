import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design_system.dart';

final _financeMoney = NumberFormat('#,###', 'en_US');
final _financeDisplayDate = DateFormat('dd.MM.yyyy');
final _financeServerDate = DateFormat('yyyy-MM-dd');

String _financeWon(num value) => '₩${_financeMoney.format(value.round())}';
String _financeSignedWon(num value) {
  final amount = value.round();
  if (amount > 0) return '+₩${_financeMoney.format(amount)}';
  if (amount < 0) return '−₩${_financeMoney.format(amount.abs())}';
  return '₩0';
}

String _financeSignedPercent(num value) {
  final amount = value.toDouble();
  if (amount > 0) return '+${amount.toStringAsFixed(1)}%';
  if (amount < 0) return '−${amount.abs().toStringAsFixed(1)}%';
  return '0.0%';
}

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
  bool _loadInFlight = false;
  String period = 'month';
  String? customPeriodLabel;
  Map<String, dynamic> report = <String, dynamic>{};
  List<Map<String, dynamic>> expenses = <Map<String, dynamic>>[];
  int inventoryStockCost = 0;
  int allTimeSoldCost = 0;

  Future<dynamic> _rpc(
    String name, {
    Map<String, dynamic>? params,
  }) async {
    final response = await client.functions.invoke(
      'admin-rpc',
      body: {'name': name, 'params': params ?? <String, dynamic>{}},
    );
    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (data['ok'] != true) {
      throw StateError((data['error'] ?? 'Moliya amali bajarilmadi.').toString());
    }
    return data['data'];
  }

  static const periodLabels = <String, String>{
    'last_month': 'O‘tgan oy',
    'last_week': 'O‘tgan hafta',
    'yesterday': 'Kecha',
    'today': 'Bugun',
    'week': 'Shu hafta',
    'month': 'Shu oy',
  };

  static const _monthNames = <String>[
    'Yanvar',
    'Fevral',
    'Mart',
    'Aprel',
    'May',
    'Iyun',
    'Iyul',
    'Avgust',
    'Sentabr',
    'Oktabr',
    'Noyabr',
    'Dekabr',
  ];

  static const categoryLabels = <String, String>{
    'postage': 'Pochta',
    'inventory_purchase': 'Yangi partiya kitoblar',
    'packaging': 'Qadoqlash',
    'ads': 'Reklama',
    'transport': 'Transport',
    'other': 'Boshqa',
  };


  // FINANCE_PERIOD_FILTERS_V2
  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  Future<void> _openPeriodFilter() async {
    final now = DateTime.now();
    final latestFinanceYear = now.year < 2026 ? 2026 : now.year;
    var selectedYear = latestFinanceYear;
    var selectedMonth = now.month;

    if (period.startsWith('range:')) {
      final parts = period.split(':');
      if (parts.length >= 3) {
        final parsed = DateTime.tryParse(parts[1]);
        if (parsed != null &&
            parsed.year >= 2026 &&
            parsed.year <= latestFinanceYear) {
          selectedYear = parsed.year;
          selectedMonth = parsed.month;
        }
      }
    }

    final selected = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Moliya davrini tanlang',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          tooltip: 'Yopish',
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Yil',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      items: [
                        for (
                          var year = latestFinanceYear;
                          year >= 2026;
                          year--
                        )
                          DropdownMenuItem<int>(
                            value: year,
                            child: Text('$year-yil'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedYear = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          <String, int>{
                            'year': selectedYear,
                            'month': 0,
                          },
                        ),
                        icon: const Icon(Icons.date_range_rounded),
                        label: Text('Butun $selectedYear-yilni ko‘rsatish'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Oy',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      items: [
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem<int>(
                            value: month,
                            child: Text(_monthNames[month - 1]),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedMonth = value);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          <String, int>{
                            'year': selectedYear,
                            'month': selectedMonth,
                          },
                        ),
                        icon: const Icon(Icons.filter_alt_rounded),
                        label: const Text('Shu davrni ko‘rsatish'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    final year = selected['year']!;
    final month = selected['month']!;

    if (month == 0) {
      setState(() {
        period = 'range:$year-01-01:$year-12-31';
        customPeriodLabel = '$year — butun yil';
      });
      await _load();
      return;
    }

    final lastDay = DateTime(year, month + 1, 0).day;
    final start = '$year-${_twoDigits(month)}-01';
    final end = '$year-${_twoDigits(month)}-${_twoDigits(lastDay)}';

    setState(() {
      period = 'range:$start:$end';
      customPeriodLabel = '$year ${_monthNames[month - 1]}';
    });
    await _load();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // Moliya RPC'lari og'irroq: fon refreshni siyraklashtiramiz va
    // oldingi yuklash tugamasdan yangi paketni boshlamaymiz.
    timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_load(quiet: true)),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  int _int(String key) => (report[key] as num?)?.round() ?? 0;
  double _double(String key) => (report[key] as num?)?.toDouble() ?? 0;

  int get _cashResult {
    final raw = report['cash_result'];
    if (raw is num) return raw.round();
    return _int('net_profit');
  }

  DateTime _expenseDate(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString());
    if (parsed == null) return DateTime.now();
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<DateTime?> _pickExpenseDate(
    BuildContext context,
    DateTime current,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(2020, 1, 1);
    var initial = DateTime(current.year, current.month, current.day);
    if (initial.isAfter(today)) initial = today;
    if (initial.isBefore(firstDate)) initial = firstDate;

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: today,
      helpText: 'Xarajat sanasini tanlang',
      cancelText: 'Bekor qilish',
      confirmText: 'Tanlash',
    );
  }

  Widget _dateButton({
    required BuildContext dialogContext,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final picked = await _pickExpenseDate(dialogContext, value);
          if (picked != null) onChanged(picked);
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text('Xarajat sanasi: ${_financeDisplayDate.format(value)}'),
        ),
      ),
    );
  }

  Future<void> _load({bool quiet = false}) async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    if (!quiet && mounted) setState(() => loading = true);
    try {
      final result = await Future.wait<dynamic>([
        _rpc(
          'admin_finance_report',
          params: {'p_secret': widget.secret, 'p_period': period},
        ),
        _rpc(
          'admin_finance_expenses',
          params: {'p_secret': widget.secret, 'p_limit': 100},
        ),
        _rpc(
          'admin_list_books',
          params: {'p_secret': widget.secret},
        ),
        _rpc(
          'admin_finance_report',
          params: {'p_secret': widget.secret, 'p_period': 'all'},
        ),
      ]);
      if (!mounted) return;
      final rawReport = result[0];
      final rawExpenses = result[1];
      final rawBooks = result[2];
      final rawAllReport = result[3];
      final soldCostAll = rawAllReport is Map
          ? ((rawAllReport['cost_of_goods'] as num?)?.round() ?? 0)
          : 0;
      var stockCost = 0;
      if (rawBooks is List) {
        for (final row in rawBooks.whereType<Map>()) {
          final stock = (row['stock'] as num?)?.round() ?? 0;
          final costPrice = (row['cost_price'] as num?)?.round() ?? 0;
          if (stock > 0 && costPrice > 0) {
            stockCost += stock * costPrice;
          }
        }
      }
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
        inventoryStockCost = stockCost;
        allTimeSoldCost = soldCostAll;
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
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> _addExpense() async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var category = 'postage';
    var expenseDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Xarajat qo‘shish'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Xarajat turi'),
                  items: categoryLabels.entries
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _dateButton(
                  dialogContext: dialogContext,
                  value: expenseDate,
                  onChanged: (value) {
                    setDialogState(() => expenseDate = value);
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
                  decoration: InputDecoration(
                    labelText: 'Izoh (ixtiyoriy)',
                    hintText: category == 'inventory_purchase'
                        ? 'Masalan: Toshkent yangi kitoblar partiyasi'
                        : 'Masalan: CJ pochta, reklama yoki qadoqlash',
                  ),
                ),
              ],
            ),
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

    final value =
        int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
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
      await _rpc(
        'admin_add_finance_expense',
        params: {
          'p_secret': widget.secret,
          'p_amount': value,
          'p_category': category,
          'p_note': noteText,
          'p_expense_date': _financeServerDate.format(expenseDate),
        },
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xarajat saqlanmadi: $e')),
      );
    }
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    final currentAmount = (expense['amount'] as num?)?.round() ?? 0;
    final amount = TextEditingController(text: currentAmount.toString());
    final note = TextEditingController(
      text: (expense['note'] ?? '').toString(),
    );
    var category = (expense['category'] ?? 'other').toString();
    if (!categoryLabels.containsKey(category)) category = 'other';
    var expenseDate = _expenseDate(expense['expense_date']);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Xarajatni tahrirlash'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Xarajat turi'),
                  items: categoryLabels.entries
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _dateButton(
                  dialogContext: dialogContext,
                  value: expenseDate,
                  onChanged: (value) {
                    setDialogState(() => expenseDate = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Summa (₩)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Izoh (ixtiyoriy)',
                  ),
                ),
              ],
            ),
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

    final value =
        int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
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
      await _rpc(
        'admin_update_finance_expense',
        params: {
          'p_secret': widget.secret,
          'p_id': expense['id'],
          'p_amount': value,
          'p_category': category,
          'p_note': noteText,
          'p_expense_date': _financeServerDate.format(expenseDate),
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xarajat yangilandi.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xarajat tahrirlanmadi: $e')),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yo‘q'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _rpc(
        'admin_delete_finance_expense',
        params: {'p_secret': widget.secret, 'p_id': expense['id']},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('O‘chirilmadi: $e')),
      );
    }
  }

  IconData _expenseIcon(String category) {
    switch (category) {
      case 'inventory_purchase':
        return Icons.library_books_outlined;
      case 'postage':
        return Icons.local_shipping_outlined;
      case 'packaging':
        return Icons.inventory_2_outlined;
      case 'ads':
        return Icons.campaign_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _cashResult;
    final margin = _double('margin_percent');
    final grossPostage = _int('postage_expense');
    final coveredPostage = _int('postage_covered_by_customers');
    final storePostage = _int('store_postage_expense');
    final postageEstimated = report['postage_is_estimated'] == true;
    final resultTitle = result > 0
        ? 'SOF FOYDA'
        : result < 0
            ? 'SOF ZARAR'
            : 'SOF NATIJA';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (kIsWeb) ...[
            _WebFinanceDashboard(
              revenue: _int('total_revenue'),
              expenses: _int('cash_outflow_total'),
              profit: result,
              cost: _int('cost_of_goods'),
              selectedPeriod: period,
              customPeriodLabel: customPeriodLabel,
              onToday: () {
                setState(() {
                  period = 'today';
                  customPeriodLabel = null;
                });
                unawaited(_load());
              },
              onMonth: () {
                setState(() {
                  period = 'month';
                  customPeriodLabel = null;
                });
                unawaited(_load());
              },
              onYear: () {
                final year = DateTime.now().year < 2026
                    ? 2026
                    : DateTime.now().year;
                setState(() {
                  period = 'range:$year-01-01:$year-12-31';
                  customPeriodLabel = '$year — butun yil';
                });
                unawaited(_load());
              },
              onFilter: () => unawaited(_openPeriodFilter()),
              onAddExpense: _addExpense,
            ),
            const SizedBox(height: 20),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moliya va sof foyda',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Web, APK, Telegram va Instagram moliyasi bitta server hisobotida.',
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
              children: [
                ...periodLabels.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: period == entry.key,
                    onSelected: (_) {
                      setState(() {
                        period = entry.key;
                        customPeriodLabel = null;
                      });
                      unawaited(_load());
                    },
                  );
                }),
                FilterChip(
                  avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: Text(
                    customPeriodLabel == null
                        ? 'Filtr'
                        : 'Filtr: $customPeriodLabel',
                  ),
                  selected: customPeriodLabel != null,
                  onSelected: (_) => unawaited(_openPeriodFilter()),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1000
                    ? 3
                    : width >= 650
                        ? 2
                        : 1;
                final itemWidth = (width - (columns - 1) * 12) / columns;
                final cards = <Widget>[
                  _FinanceCard(
                    title: 'Jami tushum',
                    value: _financeWon(_int('total_revenue')),
                    subtitle: 'Kitob + mijoz to‘lagan pochta',
                    icon: Icons.payments_outlined,
                  ),
                  _FinanceCard(
                    title: 'Hisobga kiradigan kitob savdosi',
                    value: _financeWon(_int('books_revenue')),
                    subtitle: 'Sof natijaga aynan shu summa qo‘shiladi',
                    icon: Icons.menu_book_rounded,
                  ),
                  _FinanceCard(
                    title: 'Kitob tannarxi',
                    value: _financeWon(_int('cost_of_goods')),
                    subtitle: 'Sotilgan kitoblarning umumiy tannarxi',
                    icon: Icons.price_check_outlined,
                  ),
                  _FinanceCard(
                    title: 'Kitobdan qolgan sof foyda',
                    value: _financeSignedWon(_int('book_profit')),
                    subtitle: 'Kitob savdosi − sotilgan kitob tannarxi',
                    icon: _int('book_profit') >= 0
                        ? Icons.account_balance_wallet_outlined
                        : Icons.trending_down_rounded,
                  ),
                  _FinanceCard(
                    title: 'Yangi partiya kitoblar',
                    value: _financeWon(_int('inventory_purchases')),
                    subtitle: 'Kitoblar uchun kiritilgan umumiy xarajat',
                    icon: Icons.library_books_outlined,
                  ),
                  _FinanceCard(
                    title: 'Do‘kon hisobidan pochta',
                    value: _financeWon(storePostage),
                    subtitle: storePostage > 0
                        ? 'Mijoz to‘lamagan/yetmagan pochta qismi'
                        : 'Mijoz pochta xarajatini to‘liq qoplagan',
                    icon: Icons.local_shipping_outlined,
                  ),
                  _FinanceCard(
                    title: 'Boshqa chiqimlar',
                    value: _financeWon(_int('other_expenses')),
                    subtitle: 'Qadoqlash, reklama, transport va boshqa',
                    icon: Icons.receipt_long_outlined,
                  ),
                  _FinanceCard(
                    title: 'Ombor tan narxi',
                    value: _financeWon(inventoryStockCost),
                    subtitle:
                        'Hozir omborda bor kitoblarning jami tannarxi\n'
                        'Sotilgan kitoblar bilan birga jami: ${_financeWon(inventoryStockCost + allTimeSoldCost)}',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _FinanceCard(
                    title: resultTitle,
                    value: _financeSignedWon(result),
                    subtitle: 'Marja ${_financeSignedPercent(margin)}',
                    icon: result > 0
                        ? Icons.trending_up_rounded
                        : result < 0
                            ? Icons.trending_down_rounded
                            : Icons.horizontal_rule_rounded,
                    strong: true,
                  ),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map((card) => SizedBox(width: itemWidth, child: card))
                      .toList(),
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
                    Text('📦 Jo‘natilgan: ${_int('shipped_orders')} ta'),
                    Text(
                      '📚 Kitob savdosi: ${_financeWon(_int('books_revenue'))}',
                    ),
                    Text(
                      '🚚 Mijoz to‘lagan pochta: ${_financeWon(_int('delivery_revenue'))}',
                    ),
                    Text(
                      '📮 Jami pochta${postageEstimated ? ' (taxmin)' : ''}: ${_financeWon(grossPostage)}',
                    ),
                    Text('✅ Mijoz qoplagan: ${_financeWon(coveredPostage)}'),
                    Text('🏪 Do‘kon hisobidan: ${_financeWon(storePostage)}'),
                    Text(
                      '💸 Jami hisobga kiradigan xarajat: ${_financeWon(_int('cash_outflow_total'))}',
                    ),
                    Text('📊 Natija: ${_financeSignedWon(result)}'),
                    Text('📈 Marja: ${_financeSignedPercent(margin)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 10,
                  children: [
                    Text(
                      'ℹ️ Sotilgan kitob tannarxi: ${_financeWon(_int('cost_of_goods'))}',
                    ),
                    Text(
                      '📖 Kitobdan qolgan sof foyda: ${_financeSignedWon(_int('book_profit'))}',
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chiqimlar tarixi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Yangilash',
              ),
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
            ...expenses.map(
              (e) {
                final category = (e['category'] ?? 'other').toString();
                final date = _expenseDate(e['expense_date']);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_expenseIcon(category)),
                    ),
                    title: Text(
                      '${categoryLabels[category] ?? 'Boshqa'} — ${_financeWon((e['amount'] as num?) ?? 0)}',
                    ),
                    subtitle: Text(
                      [
                        _financeDisplayDate.format(date),
                        if ((e['note'] ?? '').toString().trim().isNotEmpty)
                          (e['note'] ?? '').toString(),
                        (e['source'] ?? '').toString() == 'telegram'
                            ? 'Telegramdan kiritilgan'
                            : 'Admin ilovadan kiritilgan',
                      ].join(' • '),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Amallar',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (action) {
                        if (action == 'edit') {
                          unawaited(_editExpense(e));
                        } else if (action == 'delete') {
                          unawaited(_deleteExpense(e));
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 10),
                              Text('Tahrirlash'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded),
                              SizedBox(width: 10),
                              Text('O‘chirish'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Hisob formulasi: KITOB SAVDOSI − YANGI PARTIYA KITOBLAR − DO‘KON HISOBIDAN POCHTA − BOSHQA XARAJATLAR. Xarajatlar Bugun, Shu hafta va Shu oy bo‘limlarida kiritilgan vaqtga emas, tanlangan xarajat sanasiga qarab hisoblanadi. Mijoz yetkazish uchun to‘lagan pul foyda sifatida qo‘shilmaydi.',
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebFinanceDashboard extends StatelessWidget {
  const _WebFinanceDashboard({
    required this.revenue,
    required this.expenses,
    required this.profit,
    required this.cost,
    required this.selectedPeriod,
    required this.customPeriodLabel,
    required this.onToday,
    required this.onMonth,
    required this.onYear,
    required this.onFilter,
    required this.onAddExpense,
  });

  final int revenue;
  final int expenses;
  final int profit;
  final int cost;
  final String selectedPeriod;
  final String? customPeriodLabel;
  final VoidCallback onToday;
  final VoidCallback onMonth;
  final VoidCallback onYear;
  final VoidCallback onFilter;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final maxValue = <int>[
      revenue.abs(),
      expenses.abs(),
      profit.abs(),
      cost.abs(),
      1,
    ].reduce((a, b) => a > b ? a : b);

    final currentYear = DateTime.now().year < 2026 ? 2026 : DateTime.now().year;
    final yearSelected = selectedPeriod.startsWith('range:$currentYear-01-01');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E4B51), Color(0xFF0A6662)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moliya',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Savdo va xarajatlar nazorati',
                      style: TextStyle(
                        color: Color(0xFFD5ECE8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Xarajat'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'today', label: Text('Bugun')),
                  ButtonSegment(value: 'month', label: Text('Oy')),
                  ButtonSegment(value: 'year', label: Text('Yil')),
                ],
                selected: <String>{
                  selectedPeriod == 'today'
                      ? 'today'
                      : yearSelected
                          ? 'year'
                          : 'month',
                },
                onSelectionChanged: (value) {
                  final selected = value.first;
                  if (selected == 'today') {
                    onToday();
                  } else if (selected == 'year') {
                    onYear();
                  } else {
                    onMonth();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onFilter,
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(customPeriodLabel ?? 'Filtr'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 850 ? 4 : 2;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _WebFinanceMetric(
                  width: width,
                  title: 'Kirim',
                  value: _financeWon(revenue),
                  icon: Icons.south_west_rounded,
                ),
                _WebFinanceMetric(
                  width: width,
                  title: 'Chiqim',
                  value: _financeWon(expenses),
                  icon: Icons.north_east_rounded,
                ),
                _WebFinanceMetric(
                  width: width,
                  title: 'Foyda',
                  value: _financeSignedWon(profit),
                  icon: Icons.trending_up_rounded,
                ),
                _WebFinanceMetric(
                  width: width,
                  title: 'Tannarx',
                  value: _financeWon(cost),
                  icon: Icons.inventory_2_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        AppSurface(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Moliyaviy ko‘rinish',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _WebFinanceBar(
                      label: 'Kirim',
                      fraction: revenue.abs() / maxValue,
                      value: _financeWon(revenue),
                    ),
                    _WebFinanceBar(
                      label: 'Chiqim',
                      fraction: expenses.abs() / maxValue,
                      value: _financeWon(expenses),
                    ),
                    _WebFinanceBar(
                      label: 'Foyda',
                      fraction: profit.abs() / maxValue,
                      value: _financeSignedWon(profit),
                    ),
                    _WebFinanceBar(
                      label: 'Tannarx',
                      fraction: cost.abs() / maxValue,
                      value: _financeWon(cost),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WebFinanceMetric extends StatelessWidget {
  const _WebFinanceMetric({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });

  final double width;
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AppSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
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

class _WebFinanceBar extends StatelessWidget {
  const _WebFinanceBar({
    required this.label,
    required this.fraction,
    required this.value,
  });

  final String label;
  final double fraction;
  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = fraction.clamp(0.08, 1.0).toDouble();
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: normalized,
                  widthFactor: .55,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: strong ? 23 : 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
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
