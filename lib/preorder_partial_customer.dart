import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'app_state.dart';
import 'web_preorders.dart';
import 'uzbek_customer_style.dart';

/// Customer continuation of the SAME preorder: only received books are payable.
/// No new regular cart or second advance is created on this page.
class CustomerPartialPreorderPage extends StatefulWidget {
  const CustomerPartialPreorderPage({super.key, required this.preorderId});
  final String preorderId;
  @override
  State<CustomerPartialPreorderPage> createState() => _CustomerPartialPreorderPageState();
}

class _CustomerPartialPreorderPageState extends State<CustomerPartialPreorderPage> {
  Map<String, dynamic>? detail;
  String? error;
  bool busy = false;
  bool showingMissing = false;
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  String delivery = '택배';

  String won(num value) => '₩' + NumberFormat('#,###').format(value);

  List<Map<String, dynamic>> get original =>
      (detail?['original_items'] as List? ?? const [])
      .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();

  List<Map<String, dynamic>> get batches =>
      (detail?['batches'] as List? ?? const [])
      .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();

  List<Map<String, dynamic>> get markedMissing =>
      (detail?['missing_items'] as List? ?? const [])
      .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();

  Map<String, dynamic>? get active {
    for (final batch in batches.reversed) {
      if (batch['status'] != 'cancelled') return batch;
    }
    return null;
  }

  List<Map<String, dynamic>> get arrived {
    final values = <Map<String, dynamic>>[];
    for (final batch in batches) {
      if (batch['status'] == 'cancelled') continue;
      for (final row in (batch['items'] as List? ?? const [])) {
        if (row is Map) values.add(Map<String, dynamic>.from(row));
      }
    }
    return values;
  }

  int arrivedFor(int index) {
    var value = 0;
    for (final row in arrived) {
      if ((row['index'] as num?)?.toInt() == index) {
        value += (row['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return value;
  }

  int missingFor(int index) {
    var value = 0;
    for (final row in markedMissing) {
      if ((row['index'] as num?)?.toInt() == index) {
        value += (row['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return value;
  }

  int get missingTotal {
    var value = 0;
    for (var i = 0; i < original.length; i++) {
      final qty = (original[i]['quantity'] as num?)?.toInt() ?? 0;
      value += (qty - arrivedFor(i)).clamp(0, 100000);
    }
    return value;
  }

  int get arrivedTotal => arrived.fold<int>(
      0, (v, row) => v + ((row['quantity'] as num?)?.toInt() ?? 0));

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppState>().savedCustomer;
    name = TextEditingController(text: saved['name'] ?? '');
    phone = TextEditingController(text: saved['phone'] ?? '');
    address = TextEditingController(text: saved['address'] ?? '');
    _reload();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final value = await context.read<AppState>()
          .webPreorderPartial(widget.preorderId, 'detail');
      if (!mounted) return;
      setState(() { detail = value; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _choose() async {
    if (busy || form.currentState?.validate() != true) return;
    setState(() => busy = true);
    try {
      final value = await context.read<AppState>().webPreorderPartial(
        widget.preorderId, 'choose', {
          'choice': 'all',
          'recipient_name': name.text.trim(),
          'recipient_phone': phone.text.replaceAll(RegExp(r'[^0-9]'), ''),
          'address': address.text.trim(),
          'delivery_type': delivery,
        },
      );
      if (mounted) setState(() => detail = value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hisob saqlanmadi: ' + e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submitProof() async {
    if (busy) return;
    final due = (active?['amount_due'] as num?)?.toInt() ?? 0;
    if (due <= 0) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 1440, maxHeight: 2400,
      imageQuality: 78,
    );
    if (file == null || !mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: const Text('Qolgan to‘lov cheki'),
        content: Text(won(due) +
            ' o‘tkazganingizni tasdiqlang. Oldingi avans bu summadan ayrilgan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chekni yuborish')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      final value = await context.read<AppState>()
          .submitWebPreorderPartialProof(widget.preorderId, file);
      if (!mounted) return;
      setState(() => detail = value);
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('To‘lov cheki yuborildi ✅'),
        content: const Text('Oldingi avans kelgan kitoblarga hisoblandi. '
          'Qolgan to‘lov cheki eski buyurtmangizga biriktirildi. '
          'Admin to‘lovni tekshiradi.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Tushunarli'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chek yuborilmadi: ' + e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _arrivedSection() {
    final batch = active;
    final status = (batch?['status'] ?? '').toString();
    final subtotal = (batch?['subtotal'] as num?)?.toInt() ?? 0;
    final applied = (batch?['deposit_applied'] as num?)?.toInt() ?? 0;
    final due = (batch?['amount_due'] as num?)?.toInt() ?? 0;
    final refund = (batch?['refund_due'] as num?)?.toInt() ?? 0;
    final shipping = (batch?['shipping_fee'] as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final row in arrived)
        Card(child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text((row['requested_title'] ?? row['title'] ?? 'Kitob').toString()),
          subtitle: Text((row['quantity'] ?? 0).toString() + ' dona'),
          trailing: Text(won(((row['quantity'] as num?)?.toInt() ?? 0) *
              ((row['unit_price'] as num?)?.toInt() ?? 0))),
        )),
      const SizedBox(height: 10),
      if (status == 'prepared') ...[
        Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Form(key: form, child: Column(children: [
            const Text('Qabul qiluvchi va yetkazishni tasdiqlang',
                style: TextStyle(fontWeight: FontWeight.w800)),
            TextFormField(controller: name,
              decoration: const InputDecoration(labelText: 'Ism'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Ismni kiriting' : null),
            TextFormField(controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon (010...)'),
              validator: (v) => RegExp(r'^010[0-9]{8}$').hasMatch(
                (v ?? '').replaceAll(RegExp(r'[^0-9]'), ''))
                ? null : 'Koreya telefon raqamini kiriting'),
            DropdownButtonFormField<String>(
              value: delivery,
              decoration: const InputDecoration(labelText: 'Yetkazish usuli'),
              items: const [
                DropdownMenuItem(value: '택배',
                  child: Text('Pochta (택배)')),
                DropdownMenuItem(value: '경산 직접수령',
                  child: Text('Gyeongsan — olib ketish')),
              ],
              onChanged: (v) => setState(() => delivery = v ?? '택배'),
            ),
            TextFormField(controller: address,
              decoration: const InputDecoration(labelText: 'Manzil'),
              validator: (v) => delivery == '경산 직접수령' ||
                  (v ?? '').trim().length >= 8 ? null : 'To‘liq manzilni kiriting'),
          ]))),
        ),
        Card(color: const Color(0xFFFFF7EB), child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Oldin to‘langan avansning hali ishlatilmagan qismi '
              'TO‘LIQ kelgan kitoblarga hisoblanadi. '
              'Kelmagan kitoblar uchun yangi avans olinmaydi. '
              'Yakuniy summa yetkazish turi tanlangach hisoblanadi.'),
        )),
        FilledButton(
          onPressed: busy ? null : _choose,
          child: const Text('Kelgan kitoblar hisobini tasdiqlash'),
        ),
      ] else ...[
        Card(child: Padding(padding: const EdgeInsets.all(16),
          child: Column(children: [
            _amount('Kelgan kitoblar', subtotal),
            _amount('Yetkazish', shipping),
            _amount('To‘langan avans', -applied),
            const Divider(),
            _amount('Qolgan to‘lov', due, bold: true),
            if (refund > 0)
              _amount('Admin qaytaradigan ortiqcha avans', refund),
          ]),
        )),
        if (status == 'awaiting_payment' && due > 0)
          FilledButton.icon(onPressed: busy ? null : _submitProof,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Qolgan to‘lov chekini yuborish')),
        if (status == 'awaiting_payment' && due == 0)
          const Card(child: ListTile(
            leading: Icon(Icons.check_circle_outline, color: Colors.green),
            title: Text('To‘lovingiz yetarli'),
            subtitle: Text('Qo‘shimcha pul o‘tkazmang. Admin buyurtmani tasdiqlaydi.'),
          )),
        if (status == 'proof_submitted')
          const Card(child: ListTile(
            leading: Icon(Icons.verified_outlined, color: Colors.green),
            title: Text('Chek yuborildi'),
            subtitle: Text('Admin to‘lovni tekshiradi. Qayta to‘lov qilmang.'),
          )),
        if (status == 'completed')
          const Card(child: ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('Kelgan kitoblaringiz tasdiqlandi'),
            subtitle: Text('Buyurtmangiz jo‘natishga tayyorlanmoqda.'),
          )),
      ],
    ]);
  }

  Widget _missingSection() {
    if (missingTotal == 0) return const Text('Kelmagan kitob qolmadi.');
    return Column(children: [
      for (var i = 0; i < original.length; i++)
        if (arrivedFor(i) < ((original[i]['quantity'] as num?)?.toInt() ?? 0))
          Card(child: ListTile(
            leading: Icon(missingFor(i) > 0
                ? Icons.cancel_outlined : Icons.schedule_outlined,
              color: missingFor(i) > 0 ? Colors.red : Colors.orange),
            title: Text((original[i]['book_title'] ?? original[i]['title'] ?? 'Kitob').toString()),
            subtitle: Text(missingFor(i) > 0
                ? 'Kelmagan — admin sizga xabar yubordi'
                : 'Hozircha kelmagan, holati aniqlanmoqda'),
            trailing: Text((((original[i]['quantity'] as num?)?.toInt() ?? 0) -
                arrivedFor(i)).toString() + ' dona'),
          )),
      const Card(child: Padding(
        padding: EdgeInsets.all(14),
        child: Text('Bu kitoblar kelgan buyurtmangiz hisobiga kiritilmagan. '
          'Ularni keyinchalik qayta oldindan buyurtma qilishingiz mumkin.'),
      )),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const WebPreorderPage())),
        icon: const Icon(Icons.refresh),
        label: const Text('Qayta buyurtma qilish'),
      ),
    ]);
  }

  Widget _amount(String title, int value, {bool bold = false}) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(title,
              style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.normal))),
          Text(value < 0 ? '−' + won(-value) : won(value),
              style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: bold ? 19 : 15)),
        ]));

  @override
  Widget build(BuildContext context) {
    final batch = active;
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(title: const Text('Oldindan buyurtma'),
        actions: [IconButton(icon: const Icon(Icons.refresh),
            onPressed: busy ? null : _reload)]),
      body: detail == null ? Center(child: Text(error ?? 'Yuklanmoqda…'))
          : ListView(padding: const EdgeInsets.all(16), children: [
        Text('Buyurtma: ' + widget.preorderId.substring(0, 8),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (batch == null)
          const Text('Kelgan kitoblar bo‘yicha xabar hozircha yo‘q.')
        else ...[
          const Text('Qisman keldi',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => setState(() => showingMissing = false),
              child: Text('Keldi (' + arrivedTotal.toString() + ')'))),
            const SizedBox(width: 7),
            Expanded(child: OutlinedButton(
              onPressed: () => setState(() => showingMissing = true),
              child: Text('Kelmagan (' + missingTotal.toString() + ')'))),
          ]),
          const SizedBox(height: 12),
          if (showingMissing) _missingSection() else _arrivedSection(),
        ],
        if (busy) const LinearProgressIndicator(),
      ]),
    );
  }
}
