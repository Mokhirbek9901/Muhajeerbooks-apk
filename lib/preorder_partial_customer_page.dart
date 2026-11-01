import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'uzbek_customer_style.dart';

/// iOS TestFlight: customers choose how the original deposit is allocated.
/// Only the authenticated backend decides balances and creates final orders.
class CustomerPartialPreorderPage extends StatefulWidget {
  const CustomerPartialPreorderPage({
    super.key,
    required this.preorderId,
    required this.initialDetail,
  });
  final String preorderId;
  final Map<String, dynamic> initialDetail;

  @override
  State<CustomerPartialPreorderPage> createState() => _CustomerPartialPreorderPageState();
}

class _CustomerPartialPreorderPageState extends State<CustomerPartialPreorderPage> {
  late Map<String, dynamic> detail;
  late final TextEditingController name;
  late final TextEditingController phone;
  final address = TextEditingController();
  final number = NumberFormat('#,##0');
  String choice = 'all';
  String deliveryType = '택배';
  bool saving = false;
  String money(dynamic n) => '₩${number.format((n as num?)?.toInt() ?? 0)}';

  @override
  void initState() {
    super.initState();
    detail = widget.initialDetail;
    name = TextEditingController(text: '${detail['customer_name'] ?? ''}');
    phone = TextEditingController(text: '${detail['phone'] ?? ''}');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get waves => ((detail['batches'] as List?) ?? const [])
      .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
  Map<String, dynamic>? get active {
    for (final w in waves.reversed) {
      if (['prepared','awaiting_payment','proof_submitted'].contains(w['status'])) return w;
    }
    return null;
  }
  List<Map<String, dynamic>> books(Map<String, dynamic> wave) =>
      ((wave['items'] as List?) ?? const [])
        .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();

  Future<void> reload() async {
    final data = await context.read<AppState>()
        .webPartialPreorder(widget.preorderId, 'detail');
    if (mounted) setState(() => detail = data);
  }

  Future<void> choose() async {
    if (saving) return;
    if (name.text.trim().length < 2 || phone.text.replaceAll(RegExp(r'[^0-9]'), '').length != 11 ||
        (deliveryType != '경산 직접수령' && address.text.trim().length < 8)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ism, telefon raqami va manzilni to‘liq kiriting')));
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avans taqsimotini tasdiqlaysizmi?'),
        content: Text(choice == 'all'
          ? 'Butun qolgan avans kelgan kitoblarga ishlatiladi. Kelmagan kitoblar yopiladi; kerak bo‘lsa yangi zakas berasiz.'
          : 'Faqat kelgan kitoblarga tegishli avans ishlatiladi. Qolgan avans va kelmagan kitoblar kutishda qoladi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Qaytish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tasdiqlash')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => saving = true);
    try {
      final data = await context.read<AppState>().webPartialPreorder(
        widget.preorderId, 'choose', {
        'choice': choice,
        'recipient_name': name.text.trim(),
        'recipient_phone': phone.text.trim(),
        'address': address.text.trim(),
        'delivery_type': deliveryType,
      });
      if (mounted) setState(() => detail = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Tanlov saqlanmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> sendProof() async {
    final wave = active;
    if (wave == null || saving) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 75, maxWidth: 1500, maxHeight: 2100);
    if (file == null || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('To‘lov chekini yuborish'),
        content: Text('Qolgan to‘lov: ${money(wave['amount_due'])}. Faqat shu summani to‘laganingizdan keyin chekni yuboring.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx,true), child: const Text('Chekni yuborish')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => saving = true);
    try {
      final data = await context.read<AppState>()
          .submitWebPartialPreorderProof(widget.preorderId, file);
      if (mounted) {
        setState(() => detail = data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chek yuborildi. Admin bankdagi to‘lovni tekshiradi.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Chek yuborilmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget waveCard(Map<String, dynamic> w) {
    final state = '${w['status'] ?? ''}';
    final isActive = active?['id'] == w['id'];
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(state == 'completed' ? 'Topshirishga o‘tkazilgan kitoblar'
             : state == 'prepared' ? 'Kelgan kitoblaringiz'
             : state == 'proof_submitted' ? 'To‘lov tekshirilmoqda'
             : 'Kelgan kitoblar uchun yakuniy hisob',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final item in books(w))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text('${item['title'] ?? item['requested_title'] ?? 'Kitob'}'),
              subtitle: Text('${item['quantity']} dona × ${money(item['unit_price'])}'),
            ),
          const Divider(),
          line('Kelgan kitoblar', w['subtotal']),
          if (state != 'prepared') ...[
            line('Pochta', w['shipping_fee']),
            line('Shu bosqichga ishlatilgan avans', w['deposit_applied'], negative:true),
            line('Qolgan to‘lov', w['amount_due'], bold: true),
            if ((w['refund_due'] as num?)?.toInt() != 0)
              Text('Ortiqcha avans: ${money(w['refund_due'])}. Qaytarish admin bilan kelishiladi.'),
          ],
          if (state == 'prepared' && isActive) ...[
            const SizedBox(height: 14),
            const Text('To‘langan avans qanday ishlatilsin?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            RadioListTile<String>(
              value: 'all', groupValue: choice,
              title: const Text('Barcha qolgan avansim kelgan kitoblarga'),
              subtitle: const Text('Kelmagan kitoblar yopiladi. Kerak bo‘lsa qayta buyurtma berasiz.'),
              onChanged: saving ? null : (v) => setState(() => choice = v ?? choice),
            ),
            RadioListTile<String>(
              value: 'keep', groupValue: choice,
              title: const Text('Kelmagan kitoblarga avansni saqlash'),
              subtitle: const Text('Kelgan kitoblar uchun tegishli avans yechiladi, qolgan avans saqlanadi.'),
              onChanged: saving ? null : (v) => setState(() => choice = v ?? choice),
            ),
            const SizedBox(height: 8),
            TextField(controller:name, decoration:const InputDecoration(labelText:'Qabul qiluvchi ism')),
            TextField(controller:phone, keyboardType:TextInputType.phone,
                decoration:const InputDecoration(labelText:'Telefon raqami')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: deliveryType,
              decoration: const InputDecoration(labelText:'Yetkazish'),
              items: const [
                DropdownMenuItem(value:'택배',child:Text('Pochta (택배)')),
                DropdownMenuItem(value:'경산 직접수령',child:Text('Gyeongsan — olib ketish')),
                DropdownMenuItem(value:'경산 무료배송',child:Text('Gyeongsan — bepul yetkazish')),
              ],
              onChanged:(v)=>setState(()=>deliveryType=v??deliveryType),
            ),
            if (deliveryType != '경산 직접수령')
              TextField(controller:address, maxLines:2,
                decoration:const InputDecoration(labelText:'To‘liq manzil')),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,
              child: FilledButton(onPressed:saving?null:choose,child:const Text('Avansni tanlash va hisoblash'))),
          ],
          if (state == 'awaiting_payment' && isActive) ...[
            const SizedBox(height: 12),
            if ((w['amount_due'] as num?)?.toInt() == 0)
              const Text('Qo‘shimcha to‘lov kerak emas. Admin tasdiqlashini kuting.')
            else SizedBox(width:double.infinity,
              child: FilledButton.icon(
                onPressed:saving?null:sendProof,
                icon:const Icon(Icons.receipt_long),
                label:const Text('Qolgan to‘lov chekini yuborish'))),
          ],
          if (state == 'proof_submitted')
            const Text('Chek yuborilgan. Ikkinchi marta to‘lov qilmang.',
              style:TextStyle(fontWeight:FontWeight.w800)),
          if (state == 'completed' && w['order_id'] != null)
            const Text('Ushbu kitoblar alohida jo‘natish buyurtmasiga o‘tkazilgan.'),
        ]),
      ),
    );
  }

  Widget line(String title,dynamic amount,{bool negative=false,bool bold=false}) => Padding(
    padding:const EdgeInsets.symmetric(vertical:4),
    child:Row(children:[
      Expanded(child:Text(title,style:TextStyle(fontWeight:bold?FontWeight.w800:FontWeight.normal))),
      Text((negative?'−':'')+money(amount),
        style:TextStyle(fontSize:bold?18:14,fontWeight:bold?FontWeight.w900:FontWeight.w600)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final pending = ((detail['items'] as List?) ?? const []).whereType<Map>()
      .where((x)=>((x['remaining_quantity'] as num?)?.toInt()??0)>0).toList();
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(title:const Text('Qisman kelgan kitoblar'), actions:[
        IconButton(onPressed:saving?null:reload,icon:const Icon(Icons.refresh))]),
      body: ListView(padding:const EdgeInsets.fromLTRB(16,16,16,40),children:[
        if (saving) const LinearProgressIndicator(),
        Text('Umumiy to‘langan avans: ${money(detail['deposit_amount'])}',
           style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
        Text('Hali ishlatilmagan avans: ${money(detail['deposit_remaining'])}'),
        const SizedBox(height:16),
        for (final w in waves) if (w['status']!='cancelled') waveCard(w),
        if (pending.isNotEmpty) ...[
          const Text('Hali kelmagan kitoblar',
            style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
          for (final x in pending) ListTile(
            leading:const Icon(Icons.hourglass_empty),
            title:Text('${x['book_title'] ?? 'Kitob'}'),
            trailing:Text('${x['remaining_quantity']} dona'),
          ),
        ] else if (detail['closed']==true)
          const Text('Qolgan kitoblar yopilgan. Ularni xohlasangiz qayta buyurtma qilishingiz mumkin.'),
        if (waves.isEmpty) const Text('Hozircha qisman kelgan kitoblar belgilanmagan.'),
      ]),
    );
  }
}
