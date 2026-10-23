part of 'admin_ui.dart';

/// Shared definitions for the dashboard cards and order-list filters. Counts
/// and drill-downs must include exactly the same orders, without modifying
/// order status, inventory, or sales data.
bool _adminAwaitingPreparation(ShopOrder order) =>
    (order.status == 'accepted' || order.status == 'paid') &&
    order.preparedAt == null;

bool _adminPreparedForDispatch(ShopOrder order) =>
    (order.status == 'accepted' || order.status == 'paid') &&
    order.preparedAt != null;

bool _adminRecognizedTodaySale(ShopOrder order, DateTime now) {
  final created = order.createdAt.toLocal();
  return created.year == now.year &&
      created.month == now.month &&
      created.day == now.day &&
      (order.status == 'shipping' ||
        (order.isApp && (order.status == 'accepted' || order.status == 'paid')));
}

/// The compact admin landing page. Existing operational pages are kept intact
/// and remain reachable from these six topic-based menus.
class _AdminCommandCenter extends StatefulWidget {
  const _AdminCommandCenter({
    super.key,
    required this.api,
    required this.onOpenTab,
    required this.onPushSettings,
  });
  final _AdminApi api;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onPushSettings;

  @override
  State<_AdminCommandCenter> createState() => _AdminCommandCenterState();
}

class _AdminHomeData {
  const _AdminHomeData({
    required this.books,
    required this.orders,
    required this.todayRevenue,
    required this.newOrders,
    required this.acceptedOrders,
    required this.preparedOrders,
    required this.soldOutCount,
    this.preorderCount,
  });
  final List<Book> books;
  final List<ShopOrder> orders;
  final int todayRevenue;
  final int newOrders;
  final int acceptedOrders;
  final int preparedOrders;
  final int soldOutCount;
  final int? preorderCount;
}

class _AdminMenuAction {
  const _AdminMenuAction(this.title, this.subtitle, this.icon, this.open);
  final String title;
  final String subtitle;
  final IconData icon;
  final void Function(BuildContext) open;
}

class _AdminSectionPage extends StatelessWidget {
  const _AdminSectionPage({
    required this.title,
    required this.subtitle,
    required this.actions,
  });
  final String title;
  final String subtitle;
  final List<_AdminMenuAction> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      backgroundColor: UzbekCustomerColors.background,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            itemCount: actions.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
                  child: Text(subtitle, style: const TextStyle(
                    color: AppColors.muted, height: 1.4, fontSize: 13)),
                );
              }
              final action = actions[index - 1];
              return Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF4F1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(action.icon, color: AppColors.navy),
                  ),
                  title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(action.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                  onTap: () => action.open(context),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// One read-only timeline for BOTH native and web advance reservations.
/// Administrative actions remain in their corresponding established screens.
class _CombinedPreorderPage extends StatefulWidget {
  const _CombinedPreorderPage({required this.api});
  final _AdminApi api;
  @override
  State<_CombinedPreorderPage> createState() => _CombinedPreorderPageState();
}

class _CombinedPreorderPageState extends State<_CombinedPreorderPage> {
  late Future<({List<Map<String, dynamic>> rows, List<String> errors})> future;
  String statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<({List<Map<String, dynamic>> rows, List<String> errors})> _load() async {
    final rows = <Map<String, dynamic>>[];
    final errors = <String>[];
    try {
      final native = await widget.api.nativePreordersAll();
      for (final row in native) {
        rows.add({...row, '_origin': 'native'});
      }
    } catch (e) {
      // Older backend deployments still support the waiting-only insights.
      // Never claim that the fallback is the complete history.
      errors.add('Ilovaning to‘liq tarixi olinmadi: $e');
      try {
        final insight = await widget.api.merchandisingInsights();
        for (final raw in (insight['preorders'] as List?) ?? const []) {
          if (raw is Map) {
            rows.add({...Map<String, dynamic>.from(raw), '_origin': 'native'});
          }
        }
      } catch (fallbackError) {
        errors.add('Ilovadagi kutilayotgan zakazlar ham olinmadi: $fallbackError');
      }
    }
    if (webPreordersAvailable) {
      try {
        const pageSize = 200;
        var completed = false;
        for (var offset = 0; offset < 20000; offset += pageSize) {
          final data = await WebPreorderApi().admin(
            widget.api.secret, 'list', {'limit': pageSize, 'offset': offset},
          );
          if (data is! List) {
            throw StateError('Web zakazlar ro‘yxati noto‘g‘ri qaytdi.');
          }
          for (final raw in data) {
            if (raw is Map) {
              rows.add({...Map<String, dynamic>.from(raw), '_origin': 'web'});
            }
          }
          if (data.length < pageSize) {
            completed = true;
            break;
          }
        }
        if (!completed) {
          errors.add('Web tarixi 20 000 tadan ko‘p. Qolganini alohida boshqaruv sahifasida ko‘ring.');
        }
      } catch (e) {
        errors.add('Web oldindan zakazlari to‘liq yuklanmadi: $e');
      }
    }
    rows.sort((a, b) {
      final ad = DateTime.tryParse('${a['created_at'] ?? ''}');
      final bd = DateTime.tryParse('${b['created_at'] ?? ''}');
      return (bd ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(ad ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
    return (rows: rows, errors: errors);
  }

  Future<void> _openRecord(Map<String, dynamic> row) async {
    // Open this order, not the global preorder configuration page.
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _CombinedPreorderDetailPage(
        api: widget.api, record: Map<String, dynamic>.from(row),
      ),
    ));
    if (mounted) setState(() => future = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(
      title: const Text('Oldindan zakazlar'),
      actions: [IconButton(
        tooltip: 'Yangilash',
        icon: const Icon(Icons.refresh),
        onPressed: () => setState(() => future = _load()),
      )],
    ),
    body: FutureBuilder<({List<Map<String, dynamic>> rows, List<String> errors})>(
      future: future,
      builder: (ctx,snapshot) {
        if (snapshot.hasError) return Center(child: Text('Yuklashda xato: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final rows = data.rows.where((row) {
          final status = '${row['status'] ?? 'waiting'}';
          return switch (statusFilter) {
            'all' => status != 'cancelled',
            'waiting' => status == 'waiting',
            'accepted' => status == 'accepted' || status == 'contacted' || status == 'ordered',
            'arrived' => status == 'arrived' || status == 'fulfilled',
            'cancelled' => status == 'cancelled',
            _ => status != 'cancelled',
          };
        }).toList();
        return RefreshIndicator(
          onRefresh: () async {
            final next = await _load();
            if (mounted) setState(() => future = Future.value(next));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16,12,16,35),
            children: [
              Text('${rows.length} ta ${statusFilter == 'cancelled' ? 'bekor qilingan' : 'oldindan buyurtma'}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: AppColors.navy)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final entry in const {
                    'all': 'Barchasi',
                    'waiting': 'Tekshirish kerak',
                    'accepted': 'Qabul qilingan',
                    'arrived': 'Yangi kelgan',
                    'cancelled': 'Bekor qilingan',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: statusFilter == entry.key,
                      onSelected: (_) => setState(() => statusFilter = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Barchasi faqat faol zakazlar. Bekor qilinganlar alohida bo‘limda. Ilova va web sanaga ko‘ra birlashtirilgan.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              if (data.errors.isNotEmpty)
                AppSurface(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ba’zi ma’lumotlar vaqtincha olinmadi',
                      style: TextStyle(fontWeight: FontWeight.w900,
                        color: AppColors.danger)),
                    ...data.errors.map((e) => Text(e,
                      style: const TextStyle(color: AppColors.danger,
                        fontSize: 11))),
                  ],
                )),
              if (data.errors.isNotEmpty)
                const SizedBox(height: 10),
              if (rows.isEmpty)
                const AppSurface(child: Text('Oldindan buyurtmalar topilmadi.'))
              else
                ...rows.map((row) {
                  final web = row['_origin'] == 'web';
                  final title = '${web ? row['book_title'] : row['title']}';
                  final price = (row['deposit_amount'] as num?)?.toInt() ?? 0;
                  final status = '${row['status'] ?? 'waiting'}';
                  final statusText = const {
                    'waiting': 'Kutilmoqda',
                    'accepted': 'Qabul qilindi',
                    'contacted': 'Bog‘lanilgan',
                    'converted': 'Buyurtmaga o‘tkazilgan',
                    'arrived': 'Kitob keldi',
                    'cancelled': 'Bekor qilindi',
                    'fulfilled': 'Yakunlandi',
                    'ordered': 'Buyurtma qilindi',
                  }[status] ?? status;
                  final phone = '${row['phone'] ?? ''}'.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 8),
                        title: Text(title, maxLines: 2,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          '${row['customer_name'] ?? 'Mijoz'} • Avans ${_won(price)}\n'
                          '${phone.isNotEmpty ? 'Tel: $phone • ' : ''}'
                          '${web ? 'Web zakaz' : 'Ilova zakazi'} • $statusText',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openRecord(row),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              const Text('Zakazni bosib to‘lov cheki va holatlarini '
                'tegishli boshqaruv sahifasida tekshiring.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Kitoblar va avans sozlamalari'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _PreorderAdminPage(api: widget.api))),
              ),
            ],
          ),
        );
      },
    ),
  );
}


class _CombinedPreorderDetailPage extends StatefulWidget {
  const _CombinedPreorderDetailPage({required this.api, required this.record});
  final _AdminApi api;
  final Map<String, dynamic> record;

  @override
  State<_CombinedPreorderDetailPage> createState() =>
      _CombinedPreorderDetailPageState();
}

class _CombinedPreorderDetailPageState extends State<_CombinedPreorderDetailPage> {
  late final Map<String, dynamic> record =
      Map<String, dynamic>.from(widget.record);
  bool saving = false;

  bool get isWeb => record['_origin'] == 'web';
  String get status => '${record['status'] ?? 'waiting'}';
  String get bookTitle => '${(isWeb ? record['book_title'] : record['title']) ?? 'Kitob'}';

  String get statusLabel => const <String, String>{
    'waiting': 'Tekshirish kerak',
    'accepted': 'Qabul qilingan',
    'contacted': 'Bog‘lanilgan',
    'arrived': 'Kitob keldi',
    'converted': 'Buyurtmaga o‘tkazilgan',
    'cancelled': 'Bekor qilingan',
    'fulfilled': 'Yakunlangan',
    'ordered': 'Buyurtma qilingan',
  }[status] ?? status;

  List<(String, String, IconData)> get actions {
    switch (status) {
      case 'waiting':
        return const [
          ('accepted', 'Qabul qilish', Icons.check_circle_outline),
          ('cancelled', 'Bekor qilish', Icons.cancel_outlined),
        ];
      case 'accepted':
        return const [
          ('arrived', 'Kitob keldi', Icons.inventory_2_outlined),
          ('cancelled', 'Bekor qilish', Icons.cancel_outlined),
        ];
      case 'contacted':
        return const [
          ('accepted', 'Qabul qilish', Icons.check_circle_outline),
          ('arrived', 'Kitob keldi', Icons.inventory_2_outlined),
          ('cancelled', 'Bekor qilish', Icons.cancel_outlined),
        ];
      case 'arrived':
        return const [
          ('cancelled', 'Bekor qilish', Icons.cancel_outlined),
        ];
      case 'cancelled':
        return const [
          ('waiting', 'Qayta ko‘rib chiqish', Icons.restart_alt_rounded),
        ];
      default:
        return const [];
    }
  }

  Future<void> _refreshRecord() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (isWeb) {
        final raw = await WebPreorderApi().admin(
          widget.api.secret, 'list', {'limit': 200, 'offset': 0});
        if (raw is! List) throw StateError('Zakazlar olinmadi');
        final same = raw.whereType<Map>().where(
          (v) => '${v['id']}' == '${record['id']}').toList();
        if (same.isEmpty) throw StateError('Zakaz birinchi ro‘yxatda topilmadi');
        if (mounted) setState(() =>
          record.addAll(Map<String, dynamic>.from(same.first)));
      } else {
        final raw = await widget.api.nativePreordersAll();
        final same = raw.where((v) => '${v['id']}' == '${record['id']}').toList();
        if (same.isEmpty) throw StateError('Zakaz topilmadi');
        if (mounted) setState(() => record.addAll(same.first));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zakaz yangilanmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _viewProof() async {
    final proof = '${record[isWeb ? 'payment_proof_url' : 'payment_proof_path'] ?? ''}'.trim();
    if (proof.isEmpty) return;
    try {
      final url = isWeb ? proof : await widget.api.paymentProofUrl(proof);
      final uri = Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Avans cheki ochilmadi');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chekni ochib bo‘lmadi: $error')),
        );
      }
    }
  }

  Future<void> _arriveWithInvoice() async {
    if (saving || isWeb) return;
    final id = int.tryParse('${record['id']}');
    if (id == null) return;
    final oldStatus = status;
    var priceText = '${record['catalog_price'] ?? 0}';
    var shippingText = '4000';
    var noteText = '';
    final key = GlobalKey<FormState>();
    final form = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
        final qty = (record['quantity'] as num?)?.toInt() ?? 1;
        final deposit = (record['deposit_amount'] as num?)?.toInt() ?? 0;
        final subtotal = (int.tryParse(priceText) ?? 0) * qty;
        final total = subtotal + (int.tryParse(shippingText) ?? 0);
        final due = total - deposit;
        return AlertDialog(
          title: const Text('Kitob keldi — to‘lov hisoblash'),
          content: SizedBox(width: 440, child: SingleChildScrollView(
            child: Form(key: key, child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$bookTitle • $qty ta',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Band qilingan: ${record['reserved_qty'] ?? 0} ta. '
                  'Erkin sotuvda: ${record['available_stock'] ?? 0} ta.'),
                const SizedBox(height: 8),
                const Text('Avval kelgan partiyani omborga kiriting. '
                  'Tizim avansli kitobni boshqalarga sotishga bermaydi.',
                  style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: priceText,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => update(() => priceText = v),
                  decoration: const InputDecoration(
                    labelText: 'Bitta kitobning yakuniy narxi (₩)',
                  ),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0)<=0
                    ? 'Narxni kiriting' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: shippingText,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => update(() => shippingText = v),
                  decoration: const InputDecoration(
                    labelText: 'Pochta to‘lovi (₩)',helperText: 'Bepul bo‘lsa 0',
                  ),
                  validator: (v) => (int.tryParse(v ?? '') ?? -1)<0
                    ? '0 yoki musbat summa kiriting' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  onChanged: (v) => noteText = v,
                  maxLength: 500, maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mijozga admin izohi (majburiy)',
                    hintText: 'Masalan: Kitobingiz keldi, qolgan to‘lovni amalga oshiring.',
                  ),
                  validator: (v) => (v ?? '').trim().length < 3
                    ? 'Kamida 3 ta belgi kiriting' : null,
                ),
                const Divider(height: 22),
                Text('Kitoblar: ${_won(subtotal)}'),
                Text('Pochta: ${_won(int.tryParse(shippingText) ?? 0)}'),
                Text('To‘langan avans: −${_won(deposit)}'),
                Text('Qolgan to‘lov: ${_won(due < 0 ? 0 : due)}',
                  style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w900,
                  )),
              ],
            )),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Hozir emas')),
            FilledButton.icon(
              icon: const Icon(Icons.send_outlined),
              label: const Text('Saqlash va mijozga xabar'),
              onPressed: () {
                if (!key.currentState!.validate()) return;
                if (due < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Jami summa avansdan kam. Narxlarni tekshiring.'),
                  ));
                  return;
                }
                Navigator.pop(ctx,{
                  'price': int.parse(priceText),
                  'shipping': int.parse(shippingText),
                  'note': noteText.trim(),
                });
              },
            ),
          ],
        );
      }),
    );
    if (form == null || !mounted) return;
    setState(() => saving = true);
    try {
      final result = await widget.api.arriveNativePreorder(
        id: id, expectedStatus: oldStatus,
        unitPrice: form['price'] as int,
        shippingFee: form['shipping'] as int,
        adminNote: form['note'] as String,
      );
      if (!mounted) return;
      setState(() {
        record['status'] = 'arrived';
        record['amount_due'] = result['amount_due'];
        record['base_total'] = result['total'];
        record['deposit_credit'] = result['deposit_credit'];
        record['reserved_qty'] = result['quantity_reserved'];
        record['admin_note'] = form['note'];
        record['payment_state'] = 'requested';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kitob band qilindi. Qolgan to‘lov ilovada ko‘rinadi ✅'),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kitob keldi saqlanmadi: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _viewRemainingProof() async {
    final path = '${record['balance_proof_path'] ?? ''}'.trim();
    if (path.isEmpty || isWeb) return;
    try {
      final url = await widget.api.paymentProofUrl(path);
      final uri = Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Chek ochilmadi');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Qolgan to‘lov cheki ochilmadi: $e')));
    }
  }

  Future<void> _confirmRemainingPayment() async {
    final id = int.tryParse('${record['id']}');
    if (id == null || saving || isWeb) return;
    final agree = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title: const Text('Qolgan to‘lovni tasdiqlaysizmi?'),
      content: Text(
        'Qolgan summa ${_won((record['amount_due'] as num?)?.toInt() ?? 0)}. '
        'Bankdagi pul va mijoz yuborgan chekni tekshirgandan keyin tasdiqlang.',
      ),
      actions: [
        TextButton(onPressed:()=>Navigator.pop(ctx,false),
          child:const Text('Orqaga')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),
          child:const Text('To‘lovni tasdiqlash')),
      ],
    ));
    if (agree != true || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.api.confirmNativePreorderPayment(id);
      if (!mounted) return;
      setState(() => record['payment_state'] = 'verified');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Qolgan to‘lov tasdiqlandi ✅')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('To‘lov tasdiqlanmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _setStatus(String target) async {
    if (saving) return;
    if (target == 'arrived' && !isWeb) {
      await _arriveWithInvoice();
      return;
    }
    var noteValue = '';
    final key = GlobalKey<FormState>();
    final requireReason = target == 'cancelled' || target == 'waiting';
    final title = const <String, String>{
      'accepted': 'Zakazni qabul qilish',
      'arrived': 'Kitob keldi',
      'cancelled': 'Zakazni bekor qilish',
      'waiting': 'Zakazni qayta ochish',
    }[target] ?? 'Zakazni boshqarish';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(target == 'accepted'
              ? 'Avans cheki va to‘lovni tekshirgach qabul qiling.'
              : target == 'arrived'
                ? 'Kitob haqiqatan kelgan bo‘lsa, holatini belgilang.'
                : target == 'cancelled'
                  ? 'Sababini yozing. Avans avtomatik qaytarilmaydi.'
                  : 'Qayta ochish sababini kiriting.'),
            const SizedBox(height: 12),
            TextFormField(
              onChanged: (value) => noteValue = value,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: requireReason
                  ? 'Sababi (majburiy)'
                  : 'Admin izohi (ixtiyoriy)',
              ),
              validator: (value) => requireReason && (value ?? '').trim().length < 3
                  ? 'Kamida 3 ta belgi kiriting' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Orqaga')),
          FilledButton(onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(ctx, true);
          }, child: const Text('Tasdiqlash')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (target == 'cancelled') {
      final really = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rostdan bekor qilasizmi?'),
          content: const Text('Bu zakaz ro‘yxatdan Bekor qilingan bo‘limiga '
            'o‘tadi. Band qilingan kitoblar sotuvga qaytadi. '
            'To‘langan avans avtomatik qaytarilmaydi.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Yo‘q, qaytish')),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ha, bekor qilish',
                style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (really != true || !mounted) return;
    }
    final note = noteValue.trim();
    setState(() => saving = true);
    try {
      if (isWeb) {
        // Web backend validates the status version to prevent stale updates.
        final result = await WebPreorderApi().admin(widget.api.secret, 'status', {
          'id': '${record['id']}',
          'status': target,
          'version': record['status_version'] ?? 1,
          'note': note,
        });
        if (result is! Map || result['status'] != target) {
          throw StateError('Server holatni tasdiqlamadi.');
        }
        record['status_version'] = result['version'] ?? record['status_version'];
      } else {
        final id = int.tryParse('${record['id']}');
        if (id == null) throw StateError('Zakaz raqami noto‘g‘ri');
        await widget.api.setNativePreorderStatus(
          id: id, expectedStatus: status, status: target, note: note,
        );
      }
      if (!mounted) return;
      setState(() => record['status'] = target);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zakaz holati saqlandi: $statusLabel ✅')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Holat saqlanmadi: $error. Ro‘yxatni yangilang.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${record['customer_name'] ?? ''}'.trim();
    final phone = '${record['phone'] ?? ''}'.trim();
    final note = '${record['note'] ?? ''}'.trim();
    final quantity = (record['quantity'] as num?)?.toInt() ??
      ((record['request_items'] as List?)?.length ?? 1);
    final amount = (record['deposit_amount'] as num?)?.toInt() ?? 0;
    final proof = '${record[isWeb ? 'payment_proof_url' : 'payment_proof_path'] ?? ''}'.trim();
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        title: const Text('Oldindan zakazni boshqarish'),
        actions: [IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'To‘lov holati va chekni yangilash',
          onPressed: saving ? null : _refreshRecord,
        )],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          AppSurface(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bookTitle, style: const TextStyle(
                fontSize: 21, fontWeight: FontWeight.w900,
                color: AppColors.navy,
              )),
              const SizedBox(height: 8),
              Text('Holat: $statusLabel',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              const Divider(height: 26),
              Text('Mijoz: ${name.isEmpty ? 'Ism kiritilmagan' : name}'),
              if (phone.isNotEmpty) Text('Telefon: $phone'),
              Text('Manba: ${isWeb ? 'Web zakaz' : 'Ilova zakazi'}'),
              Text('Miqdor: $quantity ta'),
              Text('Avans: ${_won(amount)}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Mijoz izohi: $note'),
              ],
              if (!isWeb && (record['reserved_qty'] as num? ?? 0)>0)
                Text('Bu zakaz uchun band: ${record['reserved_qty']} ta',
                  style: const TextStyle(fontWeight: FontWeight.w800,
                    color: AppColors.success)),
              if (record['amount_due'] is num) ...[
                const SizedBox(height: 12),
                Text('Asosiy summa + pochta: ${_won((record['base_total'] as num?)?.toInt() ?? 0)}'),
                Text('Avans: −${_won((record['deposit_credit'] as num?)?.toInt() ?? 0)}'),
                Text('Qo‘shimcha kitoblar: ${_won((record['extra_total'] as num?)?.toInt() ?? 0)}'),
                Text('Qolgan to‘lov: ${_won((record['amount_due'] as num?)?.toInt() ?? 0)}',
                  style: const TextStyle(fontWeight:FontWeight.w900)),
                Text('To‘lov holati: ${{
                  'requested': 'Mijoz to‘lovi kutilmoqda',
                  'proof_submitted': 'Chek yuborildi — tekshirish kerak',
                  'verified': 'To‘lov tasdiqlandi',
                  'cancelled': 'Bekor qilindi',
                }[record['payment_state']] ?? record['payment_state']}'),
                if ('${record['balance_proof_path'] ?? ''}'.trim().isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Qolgan to‘lov chekini ko‘rish'),
                    onPressed: saving ? null : _viewRemainingProof,
                  ),
                if ('${record['admin_note'] ?? ''}'.trim().isNotEmpty)
                  Text('Admin izohi: ${record['admin_note']}'),
              ],
              if (proof.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: saving ? null : _viewProof,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Avans chekini ko‘rish'),
                ),
              ],
            ],
          )),
          const SizedBox(height: 18),
          Text('Zakazni boshqarish',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (saving) const LinearProgressIndicator(),
          if (actions.isEmpty)
            const AppSurface(child: Text(
              'Bu zakazning holati yakuniy. O‘zgartirish mumkin emas.',
            )),
          ...actions.map((action) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: action.$1 == 'cancelled'
                ? OutlinedButton.icon(
                    onPressed: saving ? null : () => _setStatus(action.$1),
                    icon: Icon(action.$3,color:AppColors.danger),
                    label: Text(action.$2,
                      style: const TextStyle(color:AppColors.danger)),
                  )
                : FilledButton.icon(
                    onPressed: saving ? null : () => _setStatus(action.$1),
                    icon: Icon(action.$3),label:Text(action.$2),
                  ),
          )),
          if (!isWeb && status == 'arrived' &&
            record['payment_state'] != 'verified') ...[
            const SizedBox(height: 8),
            if (record['payment_state'] != 'proof_submitted' &&
                (record['amount_due'] as num? ?? 0) > 0)
              const Text('Mijoz hali qolgan to‘lov chekini yubormagan.',
                style: TextStyle(color: AppColors.muted))
            else
              FilledButton.icon(
                onPressed: saving ? null : _confirmRemainingPayment,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Qolgan to‘lovni tekshirib tasdiqlash'),
              ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Qabul qilingan kitoblar avtomatik band qilinadi. '
            'Bekor qilsangiz band qilingan son qaytadi. Avans esa '
            'avtomatik qaytarilmaydi. Kitob kelganda admin narx, '
            'pochta va izohni belgilaydi.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A single operational checklist without new backend writes.
/// Tapping an issue takes the administrator to the existing editable screen.
/// Customers may request missing books without an ISBN or SMS confirmation.
/// Admin explicitly manages each request state; no message is auto-sent.
class _RequestedBooksAdminPage extends StatefulWidget {
  const _RequestedBooksAdminPage({required this.api});
  final _AdminApi api;
  @override
  State<_RequestedBooksAdminPage> createState() => _RequestedBooksAdminPageState();
}

class _RequestedBooksAdminPageState extends State<_RequestedBooksAdminPage> {
  late Future<List<Map<String, dynamic>>> future;
  final Set<int> saving = {};
  String filter = 'all';
  String search = '';

  static const statusLabels = <String, String>{
    'new':'Yangi', 'reviewed':'Ko‘rib chiqildi',
    'ordered':'Buyurtma qilindi', 'fulfilled':'Topildi / keldi',
  };

  @override
  void initState() {
    super.initState();
    future = widget.api.requestedBooks();
  }

  Future<void> _update(Map<String, dynamic> row, String status) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null || saving.contains(id)) return;
    setState(() => saving.add(id));
    try {
      await widget.api.setRequestedBookStatus(id, status);
      final updated = await widget.api.requestedBooks();
      if (!mounted) return;
      setState(() => future = Future.value(updated));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('So‘rov holati: ${statusLabels[status] ?? status}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Holat saqlanmadi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(title: const Text('Mijozlar so‘ragan kitoblar'),
      actions: [IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Yangilash',
        onPressed: () => setState(() => future = widget.api.requestedBooks()))]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context,snapshot) {
        if (snapshot.hasError) return Center(child: Text('Yuklash xatosi: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final records = snapshot.data!;
        final visible = records.where((row) =>
          (filter == 'all' || row['status'] == filter) &&
          (search.isEmpty ||
            '${row['title']} ${row['author']} ${row['phone']}'
              .toLowerCase().contains(search))).toList();
        return RefreshIndicator(
          onRefresh: () async {
            final result = await widget.api.requestedBooks();
            if (mounted) setState(() => future = Future.value(result));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16,12,16,36),
            children: [
              Text('${records.length} ta kitob so‘rovi',
                style: const TextStyle(fontWeight: FontWeight.w900,
                  fontSize: 20, color: AppColors.navy)),
              const SizedBox(height: 7),
              const Text('Yangi → Ko‘rib chiqildi → Buyurtma qilindi → Topildi. '
                'Holatni o‘zgartirish avtomatik SMS yubormaydi.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => search = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  labelText: 'Kitob yoki mijoz raqami bo‘yicha qidirish',
                  prefixIcon: Icon(Icons.search_rounded))),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final key in ['all', ...statusLabels.keys])
                  ChoiceChip(
                    label: Text(key == 'all' ? 'Barchasi' :
                        (statusLabels[key] ?? key)),
                    selected: filter == key,
                    onSelected: (_) => setState(() => filter = key)),
              ]),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                const AppSurface(child: Text('Bu filtrda so‘rov topilmadi.'))
              else
                ...visible.map((row) {
                  final id = (row['id'] as num?)?.toInt();
                  final status = '${row['status'] ?? 'new'}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 6),
                        title: Text('${row['title'] ?? 'Kitob'}',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          [
                            if ('${row['author'] ?? ''}'.trim().isNotEmpty)
                              'Muallif: ${row['author']}',
                            if ('${row['phone'] ?? ''}'.trim().isNotEmpty)
                              'Telefon: ${row['phone']}',
                            'Holat: ${statusLabels[status] ?? status}',
                          ].join('\n')),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          enabled: id != null && !saving.contains(id),
                          tooltip: 'So‘rov holatini o‘zgartirish',
                          icon: saving.contains(id)
                              ? const Icon(Icons.hourglass_top_rounded)
                              : const Icon(Icons.more_vert_rounded),
                          onSelected: (next) => _update(row,next),
                          itemBuilder: (_) => statusLabels.entries
                            .map((e) => PopupMenuItem<String>(
                              value: e.key, child: Text(e.value)))
                            .toList(),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    ),
  );
}

class _AdminQualityHub extends StatefulWidget {
  const _AdminQualityHub({required this.api});
  final _AdminApi api;
  @override
  State<_AdminQualityHub> createState() => _AdminQualityHubState();
}

class _AdminQualityHubState extends State<_AdminQualityHub> {
  late Future<({List<Book> books, List<ShopOrder> orders})> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<({List<Book> books, List<ShopOrder> orders})> _load() async {
    final booksRequest = widget.api.books();
    final ordersRequest = widget.api.orders();
    return (books: await booksRequest, orders: await ordersRequest);
  }

  void _openBookFilter(String filter) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Kitoblar va ombor')),
        body: _BooksAdmin(api: widget.api, initialFilter: filter),
      ),
    )).then((_) {
      if (mounted) setState(() => future = _load());
    });
  }

  void _openTracking() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Yangi ilova zakazlari — tracking yo‘q')),
        body: _OrdersAdmin(api: widget.api, initialFilter: 'tracking_missing'),
      ),
    )).then((_) {
      if (mounted) setState(() => future = _load());
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(title: const Text('Nazorat markazi'),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => setState(() => future = _load())),
      ]),
    body: FutureBuilder<({List<Book> books, List<ShopOrder> orders})>(
      future: future,
      builder: (ctx,snapshot) {
        if (snapshot.hasError) return Center(child: Text(
          'Nazorat markazi yuklanmadi: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final books = snapshot.data!.books.where((b) => b.isActive).toList();
        final orders = snapshot.data!.orders;
        final noPages = books.where((b) => b.pageCount <= 0).length;
        final noAuthor = books.where((b) =>
          b.author.trim().isEmpty || b.author.trim() == 'Ko‘rsatilmagan').length;
        final noPublisher = books.where((b) => b.publisher.trim().isEmpty).length;
        final lowStock = books.where((b) => b.stock > 0 && b.stock <= 2).length;
        final noDescription = books.where((b) => b.description.trim().isEmpty).length;
        final tracking = orders.where(_requiresAppShipmentTracking).length;
        final items = <(String, String, int, IconData, VoidCallback)>[
          ('Sahifa soni yetishmaydi', 'Kitoblar ma’lumotini to‘ldirish',
            noPages, Icons.menu_book_outlined,
            () => _openBookFilter('missing_page_count')),
          ('Nashriyoti yo‘q', 'Nashriyot nomlarini to‘ldirish',
            noPublisher, Icons.business_outlined,
            () => _openBookFilter('missing_publisher')),
          ('Muallifi yo‘q', 'Mualliflarni to‘ldirish',
            noAuthor, Icons.person_outline,
            () => _openBookFilter('missing_author')),
          ('Tavsifi yo‘q', 'Kitob tavsiflarini to‘ldirish',
            noDescription, Icons.notes_outlined,
            () => _openBookFilter('missing_description')),
          ('Kam qolgan kitoblar', '1 yoki 2 dona qolganlar',
            lowStock, Icons.inventory_2_outlined,
            () => _openBookFilter('low_stock')),
          ('Tracking kiritilmagan', 'Faqat yangi ilova zakazlari; eski, Telegram va Instagram chiqarilgan',
            tracking, Icons.local_shipping_outlined,
            _openTracking),
        ];
        return RefreshIndicator(
          onRefresh: () async {
            final data = await _load();
            if (mounted) setState(() => future = Future.value(data));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16,16,16,36),
            children: [
              const Text('Tuzatilishi kerak bo‘lgan ma’lumotlar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: AppColors.navy)),
              const SizedBox(height: 5),
              const Text('Raqamlar joriy ombor va buyurtmalar ro‘yxatidan '
                'hisoblanadi. Hech narsa avtomatik o‘chirilmaydi.',
                style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 15),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                    leading: Icon(item.$4, color: AppColors.navy),
                    title: Text(item.$1,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(item.$2),
                    trailing: Text('${item.$3} ta',
                      style: const TextStyle(color: AppColors.navy,
                        fontWeight: FontWeight.w900)),
                    onTap: item.$5,
                  ),
                ),
              )),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text('Mijozlar so‘ragan kitoblarni boshqarish'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _RequestedBooksAdminPage(api: widget.api))),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _AdminCommandCenterState extends State<_AdminCommandCenter> {
  late Future<_AdminHomeData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_AdminHomeData> load() async {
    // Fetch in parallel to keep the landing screen responsive on mobile.
    final booksFuture = widget.api.books();
    final ordersFuture = widget.api.orders();
    final books = await booksFuture;
    final orders = await ordersFuture;
    final now = DateTime.now();
    final todayRevenue = orders.where((order) =>
        _adminRecognizedTodaySale(order, now))
      .fold<int>(0, (total, order) => total + order.total);
    final newOrders = orders.where((order) => order.status == 'new').length;
    final acceptedOrders = orders.where(_adminAwaitingPreparation).length;
    final preparedOrders = orders.where(_adminPreparedForDispatch).length;
    final soldOutCount = books.where((book) =>
      book.isActive && book.stock == 0).length;

    // The metric is shown only when every relevant source answers. A failed
    // endpoint must not silently be counted as zero customer orders.
    int? preorderCount;
    try {
      final insight = await widget.api.merchandisingInsights()
          .timeout(const Duration(seconds: 4));
      final nativeRows = insight['preorders'] as List?;
      if (nativeRows != null) {
        if (webPreordersAvailable) {
          final webRows = await WebPreorderApi().admin(widget.api.secret, 'list')
              .timeout(const Duration(seconds: 4));
          if (webRows is List) preorderCount = nativeRows.length + webRows.length;
        } else {
          preorderCount = nativeRows.length;
        }
      }
    } catch (_) {
      preorderCount = null;
    }
    return _AdminHomeData(
      books: books, orders: orders, todayRevenue: todayRevenue,
      newOrders: newOrders, acceptedOrders: acceptedOrders,
      preparedOrders: preparedOrders, soldOutCount: soldOutCount,
      preorderCount: preorderCount,
    );
  }

  void reload() {
    if (mounted) setState(() => future = load());
  }

  Future<void> reloadQuietly() async {
    try {
      final updated = await load();
      if (mounted) setState(() => future = Future.value(updated));
    } catch (_) {
      // Keep last successfully loaded data on a temporary network failure.
    }
  }

  void _goToTab(BuildContext sectionContext, int tab) {
    Navigator.of(sectionContext).pop();
    widget.onOpenTab(tab);
  }

  void _pushPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  // KPI cards are explicit drill-downs; the bottom six navigation items stay
  // unchanged. Use the same filter predicates for count and list.
  Future<void> _openOrderMetric(String title, String filter) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: _OrdersAdmin(api: widget.api, initialFilter: filter),
      ),
    ));
    if (mounted) unawaited(reloadQuietly());
  }

  Future<void> _openPreorderMetric() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _CombinedPreorderPage(api: widget.api),
    ));
    if (mounted) unawaited(reloadQuietly());
  }

  Future<void> _openSoldoutMetric(List<Book> books) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _AdminBookListPage(
        title: 'Tugagan kitoblar',
        books: books.where((b) => b.isActive && b.stock == 0).toList(),
      ),
    ));
    if (mounted) unawaited(reloadQuietly());
  }

  Future<void> _openSoldoutBooks(BuildContext sectionContext) async {
    try {
      final books = await widget.api.books();
      if (!sectionContext.mounted) return;
      _pushPage(sectionContext, _AdminBookListPage(
        title: 'Tugagan kitoblar',
        books: books.where((b) => b.isActive && b.stock == 0).toList(),
      ));
    } catch (e) {
      if (sectionContext.mounted) {
        ScaffoldMessenger.of(sectionContext).showSnackBar(
          SnackBar(content: Text('Tugagan kitoblar yuklanmadi: $e')),
        );
      }
    }
  }

  Future<void> _openBusinessTools(BuildContext sectionContext) async {
    try {
      final books = await widget.api.books();
      if (!sectionContext.mounted) return;
      _pushPage(sectionContext, WebAdminToolsPage(
        secret: widget.api.secret,
        books: books,
      ));
    } catch (e) {
      if (sectionContext.mounted) {
        ScaffoldMessenger.of(sectionContext).showSnackBar(
          SnackBar(content: Text('Biznes asboblari yuklanmadi: $e')),
        );
      }
    }
  }

  /// The only extra-tools menu. The six bottom navigation buttons already
  /// own the primary screens; the tool menu can open even if KPIs are offline.
  void openTools() {
    if (!mounted) return;
    final actions = <_AdminMenuAction>[
      _AdminMenuAction('Nazorat markazi', 'Kam qoldiq, kitob ma’lumotlari va tracking',
        Icons.health_and_safety_outlined, (ctx) => _pushPage(ctx,
          _AdminQualityHub(api: widget.api))),
      _AdminMenuAction('Pochta zakaslari', 'Manzil, jo‘natmalar va tracking',
        Icons.local_shipping_outlined, (ctx) => _pushPage(ctx,
          Scaffold(appBar: AppBar(title: const Text('Pochta zakaslari')),
            body: _ShippingQueueAdmin(api: widget.api)))),
      _AdminMenuAction('Tugagan kitoblar', 'Omborda 0 dona qolgan kitoblar',
        Icons.inventory_2_outlined, (ctx) => unawaited(_openSoldoutBooks(ctx))),
      _AdminMenuAction('Katalog tartibi', 'Mijozlar ko‘radigan kitoblarni tartiblash',
        Icons.vertical_align_top_rounded, (ctx) => _pushPage(ctx,
          _CatalogPinsAdminPage(api: widget.api))),
      if (_enhancedAdminUi)
        _AdminMenuAction('Biznes asboblari', 'Tan narx, partiyalar va taqqoslash',
          Icons.calculate_outlined, (ctx) => unawaited(_openBusinessTools(ctx))),
      _AdminMenuAction('Oldindan zakazlar', 'Ilova va web zakazlari bitta ro‘yxatda',
        Icons.event_available_outlined, (ctx) => _pushPage(ctx,
          _CombinedPreorderPage(api: widget.api))),
      _AdminMenuAction('Batafsil statistika', 'Qo‘shimcha hisobot va ko‘rsatkichlar',
        Icons.insights_outlined, (ctx) => _pushPage(ctx, Scaffold(
          appBar: AppBar(title: const Text('Batafsil statistika')),
          body: _OverviewAdmin(api: widget.api, onOpenTab: (tab) {
            Navigator.of(ctx).pop();
            Navigator.of(ctx).pop();
            widget.onOpenTab(tab);
          }),
        ))),
      _AdminMenuAction('Mijozlar', 'Ro‘yxat va mijozlar statistikasi',
        Icons.people_alt_outlined, (ctx) => _goToTab(ctx, 5)),
      _AdminMenuAction('Savdo imkoniyatlari', 'Chegirmalar, kutayotganlar va xabar yuborish',
        Icons.campaign_outlined, (ctx) => _pushPage(ctx,
          _MerchandisingAdminPage(api: widget.api))),
      _AdminMenuAction('Muhim e’lon', 'Mijozlarga ko‘rinadigan do‘kon e’loni',
        Icons.notifications_active_outlined, (ctx) => _pushPage(ctx,
          _EmergencyNoticeAdmin(api: widget.api))),
      _AdminMenuAction('Admin AI', 'Kitob va biznes bo‘yicha AI vositalar',
        Icons.auto_awesome_outlined, (ctx) => _goToTab(ctx, 7)),
      _AdminMenuAction('Admin bildirishnomalari',
        'Yangi buyurtmalar uchun push xabarlari',
        Icons.notifications_outlined, (_) => widget.onPushSettings()),
    ];
    _pushPage(context, _AdminSectionPage(
      title: 'Qo‘shimcha bo‘limlar',
      subtitle: 'Asosiy oltita sahifa faqat pastki menyuda. '
          'Bu yerda esa qolgan kerakli boshqaruv vositalari jamlangan.',
      actions: actions,
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AdminHomeData>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text('Boshqaruv ma’lumotlari yuklanmadi.'),
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: reload, icon: const Icon(Icons.refresh),
                label: const Text('Qayta urinish')),
            ]),
          ));
        }
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      return RefreshIndicator(
        onRefresh: reloadQuietly,
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D4549), Color(0xFF116B64)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(children: [
                  const MuhajeerLogoBadge(size: 46, radius: 12, showShadow: false),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MUHAJEER BOOKS', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                    SizedBox(height: 3),
                    Text('Boshqaruv paneli', style: TextStyle(color: Color(0xFFE7F3F1))),
                  ])),
                  IconButton(
                    onPressed: reload,
                    tooltip: 'Yangilash',
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              const Text('Bugungi holat', style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.navy)),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (ctx, size) {
                final columns = size.maxWidth >= 720 ? 4 : 2;
                final gap = 10.0;
                final width = (size.maxWidth - gap * (columns - 1)) / columns;
                // Card order follows the operational workflow. Every count
                // opens its own relevant and pre-filtered list.
                final metrics = <(String, String, IconData, VoidCallback)>[
                  ('Bugungi savdo', _won(data.todayRevenue), Icons.payments_outlined,
                    () => unawaited(_openOrderMetric('Bugungi savdo', 'today_sales'))),
                  ('Yangi buyurtmalar', '${data.newOrders} ta', Icons.shopping_cart_outlined,
                    () => unawaited(_openOrderMetric('Yangi buyurtmalar', 'new'))),
                  ('Qabul qilingan', '${data.acceptedOrders} ta', Icons.fact_check_outlined,
                    () => unawaited(_openOrderMetric('Qabul qilingan buyurtmalar', 'accepted'))),
                  ('Jo‘natishga tayyor', '${data.preparedOrders} ta', Icons.inventory_outlined,
                    () => unawaited(_openOrderMetric('Jo‘natishga tayyor', 'prepared'))),
                  ('Tugagan kitoblar', '${data.soldOutCount} ta', Icons.inventory_2_outlined,
                    () => unawaited(_openSoldoutMetric(data.books))),
                  ('Oldindan zakazlar', data.preorderCount == null
                    ? '—' : '${data.preorderCount} ta', Icons.event_available_outlined,
                    () => unawaited(_openPreorderMetric())),
                ];
                return Wrap(spacing: gap, runSpacing: gap, children: [
                  for (var i = 0; i < metrics.length; i++)
                    SizedBox(
                      width: width,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: metrics[i].$4,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 114),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Icon(metrics[i].$3, size: 21, color: AppColors.success),
                                  const Icon(Icons.chevron_right_rounded,
                                      size: 17, color: AppColors.muted),
                                ]),
                                const SizedBox(height: 7),
                                Text(metrics[i].$1, maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11,
                                    color: AppColors.muted, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 5),
                                Text(metrics[i].$2, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 18,
                                    fontWeight: FontWeight.w900, color: AppColors.navy)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ]);
              }),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                child: Row(children: [
                  Icon(Icons.grid_view_rounded, color: AppColors.muted, size: 19),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'Qo‘shimcha boshqaruv uchun pastdagi “Bo‘limlar”ni bosing.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  )),
                ]),
              ),
            ],
          ),
        )),
      );
    },
  );
}
