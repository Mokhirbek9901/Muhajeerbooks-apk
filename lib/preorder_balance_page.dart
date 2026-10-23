import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'customer_pin_page.dart';
import 'web_preorder_checkout_page.dart';
import 'design_system.dart';
import 'uzbek_customer_style.dart';

/// A separate prepaid-order checkout: no duplicate normal order is created.
/// The original deposit is credited exactly once on the backend.
class CustomerPreorderBalancesPage extends StatefulWidget {
  const CustomerPreorderBalancesPage({super.key,this.focusPreorderId});
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

  Future<List<Map<String,dynamic>>> loadAll() async {
    final state=context.read<AppState>();
    if (state.backendConfigured && !state.checkoutIdentityReady) return const [];
    final own=await state.myPreorderBalances();
    final lookups=await state.myDiscoveredPreorders();
    // A PIN session is required to bring other device histories together.
    // Name and phone alone never authorize cross-device history.
    final linked=await state.myPinPreorders();
    final seen=<String>{};
    final rows=<Map<String,dynamic>>[
      for(final row in own)
        if(seen.add('native:${row['id']}'))
          {...row,'source':'native','ownership':'device'},
      for(final row in lookups)
        if(seen.add('${row['source']}:${row['id']}'))
          Map<String,dynamic>.from(row),
      for(final row in linked)
        if(seen.add('${row['source']}:${row['id']}'))
          Map<String,dynamic>.from(row),
    ];
    rows.sort((a,b){
      final target=widget.focusPreorderId;
      if(target!=null){
        if('${a['id']}'==target&&'${b['id']}'!=target)return -1;
        if('${b['id']}'==target&&'${a['id']}'!=target)return 1;
      }
      final aa=DateTime.tryParse('${a['created_at']??''}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
      final bb=DateTime.tryParse('${b['created_at']??''}') ??
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
        preorderId, bookId, delta,
      );
      await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kitob qo‘shilmadi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseBook(int preorderId, String originalBookId) async {
    final available = context.read<AppState>().books
        .where((b) => b.isActive && b.stock > 0 &&
          b.id != originalBookId && b.price > 0).toList();
    Book? chosen;
    var query = '';
    chosen = await showModalBottomSheet<Book>(
      context: context, isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
        final visible = available.where((b) => b.title
          .toLowerCase().contains(query.toLowerCase())).toList();
        return SafeArea(child: Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16,
            MediaQuery.viewInsetsOf(sheet).bottom + 12),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .67,
            child: Column(children: [
              const Text('Qo‘shimcha kitob tanlash',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => update(() => query = value),
                decoration: const InputDecoration(
                  labelText: 'Kitob qidirish',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: visible.isEmpty
                ? const Center(child:Text('Sotuvdagi kitob topilmadi'))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final b = visible[i];
                      return ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(b.title, maxLines: 2),
                        subtitle: Text('${won(b.price)} • ${b.stock} ta mavjud'),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.pop(sheet, b),
                      );
                    },
                  ),
              ),
            ]),
          ),
        ));
      }),
    );
    if (chosen == null || !mounted) return;
    await extra(preorderId, chosen.id, 1);
  }

  Future<void> submitProof(int preorderId, int amount) async {
    if (busy || amount <= 0) return;
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 78, maxWidth: 1600, maxHeight: 2400,
    );
    if (file == null || !mounted) return;
    final agree = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Qolgan to‘lov cheki'),
        content: Text(
          'Bankka ${won(amount)} o‘tkazganingizni tekshiring. '
          'Avans bu summadan allaqachon ayrilgan. '
          'Rasmni yuborgandan keyin savatni o‘zgartirib bo‘lmaydi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Qaytish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chekni yuborish')),
        ],
      ),
    );
    if (agree != true || !mounted) return;
    setState(() => busy = true);
    try {
      await context.read<AppState>()
        .submitPreorderRemainingPayment(preorderId, file);
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chek yuborildi. Admin tekshiradi ✅')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chek yuborilmadi: $e')),
      );
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
    body: context.watch<AppState>().backendConfigured &&
          !context.watch<AppState>().checkoutIdentityReady
      ? Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline_rounded, size: 52),
            const SizedBox(height: 14),
            const Text('Zakazlarni ko‘rish uchun profilga kiring',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Oldingi telefon raqamingiz va PIN bilan kirsangiz, '
              'oldindan zakazlaringiz ko‘rinadi.',
              textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => const CustomerPinPage(),
                ));
                if (mounted && context.read<AppState>().checkoutIdentityReady) {
                  await refresh();
                }
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('Kirish'),
            ),
          ]),
        ))
      : FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Zakazlarni yuklab bo‘lmadi: ${snap.error}'),
        ));
        if (!snap.hasData) return const Center(
          child: CircularProgressIndicator());
        final rows = snap.data!;
        if (rows.isEmpty) return const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Bu qurilmadan zakaz topilmadi. Boshqa telefoningizdagi buyurtmalar uchun Profil → Shaxsiy PIN orqali kiring.'),
        ));
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

  Future<void> _openWebCheckout(Map<String,dynamic> record) async {
    final state=context.read<AppState>();
    if(!state.pinSessionActive) {
      await Navigator.of(context).push(MaterialPageRoute<bool>(
        settings:const RouteSettings(name:'mb:web-preorder-pin'),
        builder:(_)=>const CustomerPinPage(),
      ));
      if(!mounted||!context.read<AppState>().pinSessionActive)return;
    }
    if(!mounted)return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      settings:const RouteSettings(name:'mb:web-preorder-checkout'),
      builder:(_)=>WebPreorderCheckoutPage(
        preorderId:(record['id']??'').toString()),
    ));
    if(mounted)await refresh();
  }

  Widget _invoiceCard(Map<String, dynamic> record) {
    final source='${record['source']??'native'}';
    final contactOnly=record['ownership']=='contact' || record['ownership']=='pin';
    final readonly=source=='web'||contactOnly;
    // Native preorder IDs are numbers; web preorder IDs are UUID strings.
    final rawId=record['id'];
    final id=rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0;
    final bookId = '${record['book_id'] ?? ''}';
    // The summary is scoped to the original installation ID by Supabase.
    final info = record['invoice'] is Map
      ? Map<String, dynamic>.from(record['invoice'] as Map)
      : null;
    final status = '${record['status'] ?? ''}';
    final paymentState = '${info?['payment_state'] ?? ''}';
    final extras = ((info?['extras'] as List?) ?? const [])
      .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final due = (info?['amount_due'] as num?)?.toInt() ?? 0;
    final canEdit = !readonly && status == 'arrived' && paymentState == 'requested';
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap:source=='web'?()=>_openWebCheckout(record):null,
        child:AppSurface(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${record['title'] ?? 'Kitob'}',
            style: const TextStyle(fontSize: 19,fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          if(readonly) Text(source=='web'
            ? 'Web oldindan zakaz • ${contactOnly?'Ism va telefon bo‘yicha topildi':'Shu qurilmadan'}'
            : 'Shaxsiy PIN orqali ulangan boshqa qurilmadagi zakaz',
            style:const TextStyle(color:UzbekCustomerColors.textMuted,fontSize:12)),
          const SizedBox(height: 4),
          Text('Holat: ${status == 'arrived' ? 'Kitob keldi'
            : status == 'accepted' ? 'Qabul qilingan'
            : status == 'cancelled' ? 'Bekor qilingan'
            : 'Tekshirilmoqda'}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
          if(!readonly)
            Text('Band qilingan: ${record['reserved_quantity'] ?? 0} ta'),
          if(readonly) ...[
            const SizedBox(height:10),
            Text('Miqdor: ${record['quantity']??1} ta'),
            Text(status=='arrived'
              ? 'Kitob keldi. Hisobni ko‘rish, kitob qo‘shish va '
                'avans chegirilgan qolgan to‘lovni yuborish uchun bosing.'
              : status=='accepted'
                ? 'Zakazingiz qabul qilingan. Keyingi xabarni kuting.'
                : status=='cancelled'
                  ? 'Zakaz bekor qilingan. Katalogda oldindan sotuv ochiq bo‘lsa, shu kitobga qayta buyurtma berishingiz mumkin. Eski avans avtomatik ko‘chirilmaydi.'
                  : 'Zakazingiz holatini shu yerdan kuzatishingiz mumkin.'),
            if(source=='web') ...[
              const SizedBox(height:8),
              const Row(children:[
                Icon(Icons.shopping_bag_outlined,size:19),
                SizedBox(width:8),
                Text('Buyurtma panelini ochish',
                  style:TextStyle(fontWeight:FontWeight.w800)),
                Spacer(),
                Icon(Icons.chevron_right_rounded),
              ]),
            ],
            if(record['ownership']=='pin' && info != null) ...[
              const Divider(height:20),
              Text('Asosiy summa va pochta: ${won((info['base_total'] as num?)?.toInt() ?? 0)}'),
              Text('Qo‘shimcha kitoblar: ${won((info['extra_total'] as num?)?.toInt() ?? 0)}'),
              Text('To‘langan avans: −${won((info['deposit_credit'] as num?)?.toInt() ?? 0)}'),
              Text('Qolgan to‘lov: ${won((info['amount_due'] as num?)?.toInt() ?? 0)}',
                style:const TextStyle(fontWeight:FontWeight.w900)),
              if('${info['admin_note']??''}'.trim().isNotEmpty)
                Text('Admin izohi: ${info['admin_note']}'),
              const Text('Hisob PIN orqali faqat ko‘rish uchun ochilgan. '
                'Chek yuborish uchun asosiy buyurtma qurilmasidan foydalaning.',
                style:TextStyle(color:UzbekCustomerColors.textMuted,fontSize:12)),
            ],
            if(contactOnly && record['ownership']!='pin')
              const Text('To‘lov va chek ma’lumotlari xavfsizlik uchun '
                'faqat asl qurilmada ko‘rinadi.',
                style:TextStyle(color:UzbekCustomerColors.textMuted,fontSize:12)),
          ] else if (info == null) ...[
            const SizedBox(height: 10),
            const Text('Yakuniy narx va qolgan to‘lov haqida '
              'admin kitob kelganda xabar beradi.'),
          ] else ...[
            const Divider(height: 25),
            Text('Asosiy buyurtma va pochta: ${won((info['base_total'] as num?)?.toInt() ?? 0)}'),
            Text('Qo‘shimcha kitoblar: ${won((info['extra_total'] as num?)?.toInt() ?? 0)}'),
            Text('To‘langan avans: −${won((info['deposit_credit'] as num?)?.toInt() ?? 0)}'),
            const SizedBox(height: 6),
            Text('Qolgan to‘lov: ${won(due)}',
              style: const TextStyle(fontSize: 21,fontWeight: FontWeight.w900)),
            if ('${info['admin_note'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Admin izohi: ${info['admin_note']}'),
            ],
            if (extras.isNotEmpty) ...[
              const Divider(height: 23),
              const Text('Qo‘shimcha kitoblar',
                style: TextStyle(fontWeight:FontWeight.w800)),
              for (final item in extras) ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${item['title'] ?? 'Kitob'}'),
                subtitle: Text(
                  '${won((item['unit_price'] as num?)?.toInt() ?? 0)} × ${item['quantity']}'),
                trailing: canEdit ? IconButton(
                  onPressed: busy ? null : () =>
                    extra(id, '${item['book_id']}', -1),
                  tooltip: 'Bitta kitobni olib tashlash',
                  icon: const Icon(Icons.remove_circle_outline),
                ) : null,
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : () => chooseBook(id, bookId),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Yana kitob qo‘shish'),
              ),
              const SizedBox(height: 12),
              SelectableText(
                '${AppState.bankName} • ${AppState.bankAccount} • ${AppState.bankOwner}'),
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Bank raqamini nusxalash'),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: AppState.bankAccount));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bank raqami nusxalandi')),
                  );
                },
              ),
              if (due > 0) FilledButton.icon(
                onPressed: busy ? null : () => submitProof(id, due),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Qolgan to‘lov chekini yuborish'),
              ) else
                const Text('Qolgan to‘lov ₩0. Admin tasdig‘i kutilmoqda.'),
            ] else ...[
              const SizedBox(height: 10),
              Text(paymentState == 'proof_submitted'
                ? 'To‘lov cheki yuborilgan. Admin tekshiradi.'
                : paymentState == 'verified'
                  ? 'To‘lov tasdiqlangan ✅'
                  : paymentState == 'cancelled'
                    ? 'Zakaz bekor qilingan. Katalogda oldindan sotuv ochiq bo‘lsa, shu kitobga qayta buyurtma berishingiz mumkin. Eski avans avtomatik ko‘chirilmaydi.'
                    : 'To‘lov holati: $paymentState'),
            ],
          ],
        ],
      ))),
    );
  }
}
