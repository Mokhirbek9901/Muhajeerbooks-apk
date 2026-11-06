import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'design_system.dart';
import 'uzbek_customer_style.dart';

/// Customer-owned partial receipt. The server alone decides stock, postage,
/// advance allocation and amount due. No new order or double deposit is made.
class CustomerWebPreorderPartialPage extends StatefulWidget {
  const CustomerWebPreorderPartialPage({
    super.key,
    required this.preorderId,
    this.title = '',
  });
  final String preorderId;
  final String title;

  @override
  State<CustomerWebPreorderPartialPage> createState() =>
      _CustomerWebPreorderPartialPageState();
}

class _CustomerWebPreorderPartialPageState
    extends State<CustomerWebPreorderPartialPage> {
  final recipient = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final picker = ImagePicker();
  final money = NumberFormat('#,##0', 'en_US');
  Map<String, dynamic>? data;
  bool busy = false;
  bool loading = true;
  String? error;
  String choice = '';
  String delivery = '택배';
  int n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  String won(int v) => '₩${money.format(v)}';

  Future<void> refresh() async {
    try {
      final state = context.read<AppState>();
      final next = await state.customerWebPartial(widget.preorderId, 'detail');
      if (!mounted) return;
      setState(() {
        data = next;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        loading = false;
        error = 'Kelgan kitoblar hisobi yuklanmadi: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.read<AppState>().savedCustomer;
      recipient.text = s['name'] ?? '';
      phone.text = s['phone'] ?? '';
      address.text = s['address'] ?? '';
      refresh();
    });
  }

  @override
  void dispose() {
    recipient.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get batches =>
    (data?['batches'] as List? ?? const [])
      .whereType<Map>()
      .map((x) => Map<String, dynamic>.from(x))
      .toList();

  Map<String, dynamic>? get active {
    for (final batch in batches.reversed) {
      if (const {'prepared', 'awaiting_payment', 'proof_submitted'}
          .contains('${batch['status']}')) return batch;
    }
    return null;
  }

  Future<void> _choose() async {
    final b = active;
    if (busy || b == null || b['status'] != 'prepared') return;
    final appliedChoice = b['choice'] == 'all' ? 'all' : choice;
    if (!const {'all', 'keep'}.contains(appliedChoice)) {
      _snack('Avansdan foydalanish variantini tanlang.');
      return;
    }
    final name = recipient.text.trim();
    final digits = phone.text.replaceAll(RegExp(r'\D'), '');
    final location = address.text.trim();
    if (name.length < 2 || !RegExp(r'^010[0-9]{8}$').hasMatch(digits) ||
       (delivery != '경산 직접수령' && location.length < 8)) {
      _snack('Yetkazish uchun ism, telefon va manzilni tekshiring.');
      return;
    }
    final yes = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Avans tanlovini tasdiqlash'),
        content: Text(
          appliedChoice == 'all'
          ? 'Avansning hali ishlatilmagan qismi kelgan kitoblar va '
            'pochtaga hisoblanadi. Qolgan kitoblar uchun ushbu '
            'oldindan zakas yakunlanadi. Kerak bo‘lsa keyin yangi zakas '
            'berasiz. Ortiqcha avans bo‘lsa qaytariladigan pul ko‘rsatiladi.'
          : 'Kelgan kitoblar uchun tegishli avans ishlatiladi. '
            'Qolgan avans va topilmagan kitoblar kutishdagi zakasda qoladi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog,false),
            child: const Text('Ortga')),
          FilledButton(onPressed: () => Navigator.pop(dialog,true),
            child: const Text('Tasdiqlash')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>().customerWebPartial(
        widget.preorderId, 'choose',
        payload: {
          'choice': appliedChoice,
          'recipient_name': name,
          'recipient_phone': digits,
          'address': location,
          'delivery_type': delivery,
        },
      );
      if (mounted) await refresh();
    } catch (e) {
      if (mounted) _snack('Tanlov saqlanmadi: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendProof() async {
    if (busy) return;
    XFile? file;
    try {
      file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    } catch (e) {
      _snack('Chekni tanlab bo‘lmadi: $e');
      return;
    }
    if (file == null || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>()
        .submitWebPartialPayment(widget.preorderId,file!);
      if (mounted) {
        await refresh();
        _snack('Qolgan to‘lov cheki adminga yuborildi.');
      }
    } catch (e) {
      if (mounted) _snack('Chek yuborilmadi: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pending = (data?['items'] as List? ?? const [])
      .whereType<Map>().toList();
    final b = active;
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(title: const Text('Topilgan kitoblarim'),
        actions: [
          IconButton(onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),tooltip:'Yangilash'),
        ]),
      body: loading
      ? const Center(child: CircularProgressIndicator())
      : error != null
      ? Center(child: Padding(
        padding: const EdgeInsets.all(20),child: Text(error!)))
      : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.title.isEmpty
            ? 'Oldindan zakas' : widget.title,
            style: const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          Text('To‘langan jami avans: ${won(n(data?['deposit_amount']))}'),
          Text('Hali ishlatilmagan avans: ${won(n(data?['deposit_remaining']))}',
            style:const TextStyle(fontWeight:FontWeight.w800)),
          const SizedBox(height:12),
          for (final batch in batches) Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  batch['status']=='completed'
                    ? 'Tasdiqlangan jo‘natma'
                    : 'Topilgan kitoblar',
                  style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
                const SizedBox(height:6),
                for (final raw in (batch['items'] as List? ?? const []))
                  if(raw is Map)
                    Padding(padding:const EdgeInsets.only(bottom:4),
                      child:Text('${raw['requested_title']??raw['title']}: '
                        '${raw['quantity']} dona × ${won(n(raw['unit_price']))}')),
                Text('Kitoblar jami: ${won(n(batch['subtotal']))}'),
                if (batch['status']!='prepared') ...[
                  Text('Pochta: ${won(n(batch['shipping_fee']))}'),
                  Text('Avansdan ayirildi: −${won(n(batch['deposit_applied']))}'),
                  Text('Qolgan to‘lov: ${won(n(batch['amount_due']))}',
                    style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
                  if(n(batch['refund_due'])>0)
                    Text('Qaytarilishi kerak: ${won(n(batch['refund_due']))}',
                      style:const TextStyle(fontWeight:FontWeight.w800)),
                ],
                if (batch['status']=='completed')
                  const Text('Adminga tasdiqlangan. Jo‘natma buyurtmalaringizda ko‘rinadi.'),
              ],
            ),
          )),
          if (b?.isNotEmpty == true && b?['status']=='prepared') ...[
            const SizedBox(height:12),
            const Text('Avans qanday ishlatilsin?',
              style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
            const SizedBox(height:7),
            if (b?['choice']=='all')
              const Text('Sizning zakasingiz uchun barcha avansni kelgan '
                'kitoblarga hisoblash oldindan belgilangan.')
            else ...[
              ListTile(
                key:const Key('partial_advance_keep'),
                leading:Icon(choice=='keep'
                  ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title:const Text('Qolgan kitoblarga avans saqlansin'),
                subtitle:const Text('Kelgan kitoblar uchun tegishli avans '
                  'ayriladi, ortig‘i kelmagan kitoblar uchun qoladi.'),
                onTap:()=>setState(()=>choice='keep'),
              ),
              ListTile(
                key:const Key('partial_advance_all'),
                leading:Icon(choice=='all'
                  ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title:const Text('Barcha avans kelganlarga ishlatilsin'),
                subtitle:const Text('Qolgan kitoblar uchun ushbu zakas '
                  'yopiladi, kerak bo‘lsa qayta zakas qilasiz.'),
                onTap:()=>setState(()=>choice='all'),
              ),
            ],
            const SizedBox(height:8),
            TextField(
              controller:recipient,enabled:!busy,
              decoration:const InputDecoration(
                labelText:'Qabul qiluvchi ismi',
                border:OutlineInputBorder())),
            const SizedBox(height:9),
            TextField(
              controller:phone,enabled:!busy,
              keyboardType:TextInputType.phone,
              decoration:const InputDecoration(
                labelText:'Telefon raqami',
                border:OutlineInputBorder())),
            const SizedBox(height:9),
            DropdownButtonFormField<String>(
              value:delivery,
              decoration:const InputDecoration(
                labelText:'Yetkazish usuli',
                border:OutlineInputBorder()),
              items:const [
                DropdownMenuItem(value:'택배',child:Text('Pochta')),
                DropdownMenuItem(value:'경산 직접수령',
                  child:Text('Gyeongsan — olib ketish')),
                DropdownMenuItem(value:'경산 무료배송',
                  child:Text('Gyeongsan — bepul yetkazish')),
              ],
              onChanged:busy?null:(v){if(v!=null)setState(()=>delivery=v);},
            ),
            const SizedBox(height:9),
            if(delivery!='경산 직접수령')
              TextField(
                controller:address,enabled:!busy,
                maxLines:2,
                decoration:const InputDecoration(
                  labelText:'Yetkazish manzili',
                  border:OutlineInputBorder())),
            const SizedBox(height:12),
            FilledButton.icon(
              key:const Key('partial_choose_advance'),
              onPressed:busy?null:_choose,
              icon:const Icon(Icons.calculate_outlined),
              label:const Text('Avansni ayirib qolgan to‘lovni hisoblash')),
          ],
          if (b != null && b['status']=='awaiting_payment') ...[
            if(n(b['amount_due'])>0)
              FilledButton.icon(
                key:const Key('partial_upload_balance_proof'),
                onPressed:busy?null:_sendProof,
                icon:const Icon(Icons.receipt_long_outlined),
                label:const Text('Qolgan to‘lov chekini yuborish'))
            else
              const Text('Qolgan to‘lov ₩0. Admin tasdig‘i kutilmoqda.',
                style:TextStyle(fontWeight:FontWeight.w800)),
          ],
          if (b != null && b['status']=='proof_submitted')
            const Text('To‘lov cheki yuborildi. Admin tasdiqlashi kutilmoqda.',
              style:TextStyle(fontWeight:FontWeight.w800)),
          if (b == null && data?['closed']!=true) ...[
            const Text('Hali qisman topilgan kitoblar belgilanmagan. '
              'Kitoblar kelganda shu yerda xabar va hisob paydo bo‘ladi.'),
          ],
          if (data?['closed']!=true && pending.isNotEmpty) ...[
            const SizedBox(height:14),
            const Text('Hali topilmagan kitoblar',
              style:TextStyle(fontWeight:FontWeight.w900)),
            for(final item in pending)
              if(n(item['remaining_quantity'])>0)
                Text('• ${item['book_title']??'Kitob'}: '
                  '${item['remaining_quantity']} dona'),
          ],
          if (data?['closed']==true)
            const Text('Bu oldindan zakasning qolgan qismi yopilgan. '
              'Topilmagan kitoblarni keyin yangidan buyurtma qilishingiz mumkin.'),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height:24),
        ],
      ),
    );
  }
}
