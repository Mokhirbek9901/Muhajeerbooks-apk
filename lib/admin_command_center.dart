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
  final sold = order.recognizedSaleAt;
  if (sold == null) return false;
  return sameKoreaDay(sold, now);
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
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF4F1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(action.icon, color: AppColors.navy),
                  ),
                  title: Text(
                    action.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    action.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
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

  Future<({List<Map<String, dynamic>> rows, List<String> errors})>
  _load() async {
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
        errors.add(
          'Ilovadagi kutilayotgan zakazlar ham olinmadi: $fallbackError',
        );
      }
    }
    if (webPreordersAvailable) {
      try {
        const pageSize = 200;
        var completed = false;
        for (var offset = 0; offset < 20000; offset += pageSize) {
          final data = await WebPreorderApi().admin(widget.api.secret, 'list', {
            'limit': pageSize,
            'offset': offset,
          });
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
          errors.add(
            'Web tarixi 20 000 tadan ko‘p. Qolganini alohida boshqaruv sahifasida ko‘ring.',
          );
        }
      } catch (e) {
        errors.add('Web oldindan zakazlari to‘liq yuklanmadi: $e');
      }
    }
    rows.sort((a, b) {
      final ad = DateTime.tryParse('${a['created_at'] ?? ''}');
      final bd = DateTime.tryParse('${b['created_at'] ?? ''}');
      return (bd ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        ad ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
    return (rows: rows, errors: errors);
  }

  Future<void> _openRecord(Map<String, dynamic> row) async {
    // Open this order, not the global preorder configuration page.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CombinedPreorderDetailPage(
          api: widget.api,
          record: Map<String, dynamic>.from(row),
        ),
      ),
    );
    if (mounted) setState(() => future = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(
      title: const Text('Oldindan zakazlar'),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => future = _load()),
        ),
      ],
    ),
    body: FutureBuilder<({List<Map<String, dynamic>> rows, List<String> errors})>(
      future: future,
      builder: (ctx, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Yuklashda xato: ${snapshot.error}'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        final rows = data.rows.where((row) {
          final status = '${row['status'] ?? 'waiting'}';
          return switch (statusFilter) {
            'all' => status != 'cancelled',
            'waiting' => status == 'waiting',
            'accepted' =>
              status == 'accepted' ||
                  status == 'contacted' ||
                  status == 'ordered',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 35),
            children: [
              Text(
                '${rows.length} ta ${statusFilter == 'cancelled' ? 'bekor qilingan' : 'oldindan buyurtma'}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
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
                      onSelected: (_) =>
                          setState(() => statusFilter = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Barchasi faqat faol zakazlar. Bekor qilinganlar alohida bo‘limda. Ilova va web sanaga ko‘ra birlashtirilgan.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (data.errors.isNotEmpty)
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ba’zi ma’lumotlar vaqtincha olinmadi',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.danger,
                        ),
                      ),
                      ...data.errors.map(
                        (e) => Text(
                          e,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (data.errors.isNotEmpty) const SizedBox(height: 10),
              if (rows.isEmpty)
                const AppSurface(child: Text('Oldindan buyurtmalar topilmadi.'))
              else
                ...rows.map((row) {
                  final web = row['_origin'] == 'web';
                  final title = '${web ? row['book_title'] : row['title']}';
                  final price = (row['deposit_amount'] as num?)?.toInt() ?? 0;
                  final status = '${row['status'] ?? 'waiting'}';
                  final statusText =
                      const {
                        'waiting': 'Kutilmoqda',
                        'accepted': 'Qabul qilindi',
                        'contacted': 'Bog‘lanilgan',
                        'converted': 'Buyurtmaga o‘tkazilgan',
                        'arrived': 'Kitob keldi',
                        'cancelled': 'Bekor qilindi',
                        'fulfilled': 'Yakunlandi',
                        'ordered': 'Buyurtma qilindi',
                      }[status] ??
                      status;
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
                          horizontal: 13,
                          vertical: 8,
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
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
              const Text(
                'Zakazni bosib to‘lov cheki va holatlarini '
                'tegishli boshqaruv sahifasida tekshiring.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Kitoblar va avans sozlamalari'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _CombinedPreorderPage(api: widget.api),
                  ),
                ),
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

class _CombinedPreorderDetailPageState
    extends State<_CombinedPreorderDetailPage> {
  Map<String, dynamic>? data;
  bool saving = false;
  String? error;
  String get source =>
      '${widget.record['_origin'] ?? widget.record['source'] ?? 'native'}';
  String get reference => '${widget.record['id']}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final next = await widget.api.releasePreorder(
        source,
        reference,
        'detail',
      );
      if (mounted)
        setState(() {
          data = next;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _act(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final next = await widget.api.releasePreorder(source, reference, action, {
        ...payload,
        if (data?['revision'] != null) 'revision': data!['revision'],
      });
      if (mounted) setState(() => data = next);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saqlanmadi: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<Book?> _book(List<Book> books) async {
    var query = '';
    return showModalBottomSheet<Book>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final visible = books
              .where((b) => b.title.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * .7,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (v) => update(() => query = v),
                      decoration: const InputDecoration(
                        labelText: 'Katalogdan kitob tanlash',
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(visible[i].title),
                          subtitle: Text(
                            'Ombor: ${visible[i].stock} • ${_won(visible[i].price)}',
                          ),
                          onTap: () => Navigator.pop(ctx, visible[i]),
                        ),
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
  }

  Future<void> _invoice() async {
    final d = data;
    if (d == null) return;
    final books = await widget.api.books();
    if (!mounted) return;
    final lines = <Map<String, dynamic>>[];
    final current = (d['main_items'] as List?) ?? const [];
    if (current.isNotEmpty) {
      for (final raw in current) {
        final x = Map<String, dynamic>.from(raw as Map);
        lines.add(x);
      }
    } else if (d['request_items'] is List &&
        (d['request_items'] as List).isNotEmpty) {
      for (final raw in d['request_items'] as List) {
        final x = raw as Map;
        lines.add({
          'title': x['book_title'],
          'quantity': x['quantity'],
          'unit_price': 0,
        });
      }
    } else {
      lines.add({
        'book_id': d['book_id'],
        'title': d['title'] ?? d['book_title'],
        'quantity': d['quantity'] ?? 1,
        'unit_price': 0,
      });
    }
    var note = '${d['admin_note'] ?? ''}';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Har bir kitobning yakuniy hisobi'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Har bir so‘rovni katalogdagi kitobga bog‘lang. Omborga kelgan partiyani oldindan kiriting. Avans umumiy hisobdan bir marta ayiriladi.',
                  ),
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${lines[i]['title'] ?? 'Kitob'}'),
                            subtitle: Text(
                              lines[i]['book_id'] == null
                                  ? 'Katalog kitobini tanlang'
                                  : 'Katalogga bog‘langan',
                            ),
                            trailing: const Icon(Icons.search),
                            onTap: () async {
                              final b = await _book(books);
                              if (b != null && ctx.mounted)
                                update(
                                  () => lines[i].addAll({
                                    'book_id': b.id,
                                    'title': b.title,
                                    'unit_price': b.currentPrice,
                                  }),
                                );
                            },
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey('qty-$i'),
                                  initialValue: '${lines[i]['quantity'] ?? 1}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Miqdor',
                                  ),
                                  onChanged: (v) => lines[i]['quantity'] =
                                      int.tryParse(v) ?? 0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey(
                                    'price-$i-${lines[i]['book_id']}-${lines[i]['unit_price']}',
                                  ),
                                  initialValue:
                                      '${lines[i]['unit_price'] ?? 0}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Bitta kitob narxi ₩',
                                  ),
                                  onChanged: (v) => lines[i]['unit_price'] =
                                      int.tryParse(v) ?? 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: note,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Mijozga izoh',
                    ),
                    onChanged: (v) => note = v,
                  ),
                  Text(
                    'To‘langan avans: ${_won((d['deposit_credit'] as num?)?.toInt() ?? 0)}',
                  ),
                  const Text(
                    'Pochta va qaytariladigan ortiqcha avans serverda hisoblanadi.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hozir emas'),
            ),
            FilledButton(
              onPressed: () {
                if (lines.any(
                  (l) =>
                      l['book_id'] == null ||
                      ((l['quantity'] as num?)?.toInt() ?? 0) < 1 ||
                      ((l['unit_price'] as num?)?.toInt() ?? 0) < 1,
                ))
                  return;
                Navigator.pop(ctx, {'items': lines, 'note': note});
              },
              child: const Text('Saqlash • kitob keldi'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) await _act('invoice', result);
  }

  Future<void> _batch() async {
    final books = await widget.api.books();
    if (!mounted) return;
    final book = await _book(books);
    if (book == null || !mounted) return;
    var qty = '';
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Partiya: ${book.title}'),
        content: TextField(
          keyboardType: TextInputType.number,
          onChanged: (v) => qty = v,
          decoration: const InputDecoration(labelText: 'Kelgan nusxalar soni'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hozir emas'),
          ),
          FilledButton(
            onPressed: () {
              final q = int.tryParse(qty) ?? 0;
              if (q > 0 && q <= 2000) Navigator.pop(ctx, q);
            },
            child: const Text('Omborga qo‘shish'),
          ),
        ],
      ),
    );
    if (n == null || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.api.receiveNativePreorderBatch(bookId: book.id, quantity: n);
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zakas bekor qilinsinmi?'),
        content: const Text(
          'Bandlangan kitoblar omborga qaytadi. Avans qaytariladigan summa sifatida qayd etiladi. Bank orqali qaytarishni admin alohida bajaradi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Yo‘q'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bekor qilish'),
          ),
        ],
      ),
    );
    if (ok == true) await _act('status', {'status': 'cancelled'});
  }

  Future<void> _proof(bool balance) async {
    final path =
        '${data?[balance ? 'balance_proof_path' : 'payment_proof_path'] ?? ''}';
    if (path.isEmpty) return;
    try {
      String url;
      if (!balance && source == 'web') {
        url = '${widget.record['payment_proof_url'] ?? ''}';
      } else {
        url = await widget.api.paymentProofUrl(path);
      }
      if (url.isEmpty ||
          !await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          ))
        throw StateError('Chek ochilmadi');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oldindan zakas hisobi'),
        actions: [
          IconButton(
            onPressed: saving ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: d == null
          ? Center(
              child: error != null
                  ? Text(error!)
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${d['title'] ?? d['book_title'] ?? 'Kitob'}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${d['customer_name']} • ${d['phone']}\nHolat: ${d['status']} • To‘lov: ${d['payment_state']}',
                ),
                for (final raw in (d['items'] as List?) ?? const [])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${(raw as Map)['title']}'),
                    subtitle: Text(
                      '${raw['quantity']} × ${_won((raw['unit_price'] as num).toInt())}',
                    ),
                    trailing: Text('Band: ${raw['held']}'),
                  ),
                const Divider(),
                Text(
                  'Kitob va pochta: ${_won(((d['base_total'] as num?)?.toInt() ?? 0) + ((d['extra_total'] as num?)?.toInt() ?? 0))}',
                ),
                Text(
                  'To‘langan avans: −${_won((d['deposit_credit'] as num?)?.toInt() ?? 0)}',
                ),
                Text(
                  'Qolgan to‘lov: ${_won((d['amount_due'] as num?)?.toInt() ?? 0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Qaytariladigan pul: ${_won((d['refund_due'] as num?)?.toInt() ?? 0)}',
                ),
                if (d['delivery_saved'] == true)
                  Text(
                    'Yetkazish: ${d['recipient_name']} • ${d['recipient_phone']}\n${d['delivery_address']}',
                  ),
                if (d['converted_order_id'] != null)
                  SelectableText(
                    'Buyurtmaga o‘tkazildi: ${d['converted_order_id']}',
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: saving ? null : () => _proof(false),
                      child: const Text('Avans cheki'),
                    ),
                    if ('${d['balance_proof_path'] ?? ''}'.isNotEmpty)
                      OutlinedButton(
                        onPressed: saving ? null : () => _proof(true),
                        child: const Text('Qolgan to‘lov cheki'),
                      ),
                    if (d['status'] == 'waiting' || d['status'] == 'contacted')
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () => _act('status', {'status': 'accepted'}),
                        child: const Text('Qabul qilish'),
                      ),
                    if (d['payment_state'] == 'requested' &&
                        d['status'] != 'cancelled') ...[
                      OutlinedButton(
                        onPressed: saving ? null : _batch,
                        child: const Text('Kelgan partiyani kiritish'),
                      ),
                      FilledButton(
                        onPressed: saving ? null : _invoice,
                        child: const Text('Yakuniy narx • kitob keldi'),
                      ),
                    ],
                    if (d['price_ready'] == true &&
                        d['payment_state'] != 'cancelled' &&
                        d['converted_order_id'] == null)
                      FilledButton(
                        onPressed: saving ? null : () => _act('confirm'),
                        child: const Text(
                          'To‘lovni tasdiqlash • jo‘natishga o‘tkazish',
                        ),
                      ),
                    if (d['status'] != 'cancelled' &&
                        d['converted_order_id'] == null)
                      TextButton(
                        onPressed: saving ? null : _cancel,
                        child: const Text('Zakasni bekor qilish'),
                      ),
                  ],
                ),
                if (saving) const LinearProgressIndicator(),
              ],
            ),
    );
  }
}

class _RequestedBooksAdminPage extends StatefulWidget {
  const _RequestedBooksAdminPage({required this.api});
  final _AdminApi api;
  @override
  State<_RequestedBooksAdminPage> createState() =>
      _RequestedBooksAdminPageState();
}

class _RequestedBooksAdminPageState extends State<_RequestedBooksAdminPage> {
  late Future<List<Map<String, dynamic>>> future;
  final Set<int> saving = {};
  String filter = 'all';
  String search = '';

  static const statusLabels = <String, String>{
    'new': 'Yangi',
    'reviewed': 'Ko‘rib chiqildi',
    'ordered': 'Buyurtma qilindi',
    'fulfilled': 'Topildi / keldi',
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
        SnackBar(
          content: Text('So‘rov holati: ${statusLabels[status] ?? status}'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Holat saqlanmadi: $e')));
      }
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(
      title: const Text('Mijozlar so‘ragan kitoblar'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Yangilash',
          onPressed: () => setState(() => future = widget.api.requestedBooks()),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Yuklash xatosi: ${snapshot.error}'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final records = snapshot.data!;
        final visible = records
            .where(
              (row) =>
                  (filter == 'all' || row['status'] == filter) &&
                  (search.isEmpty ||
                      '${row['title']} ${row['author']} ${row['phone']}'
                          .toLowerCase()
                          .contains(search)),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            final result = await widget.api.requestedBooks();
            if (mounted) setState(() => future = Future.value(result));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            children: [
              Text(
                '${records.length} ta kitob so‘rovi',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Yangi → Ko‘rib chiqildi → Buyurtma qilindi → Topildi. '
                'Holatni o‘zgartirish avtomatik SMS yubormaydi.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) =>
                    setState(() => search = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  labelText: 'Kitob yoki mijoz raqami bo‘yicha qidirish',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final key in ['all', ...statusLabels.keys])
                    ChoiceChip(
                      label: Text(
                        key == 'all' ? 'Barchasi' : (statusLabels[key] ?? key),
                      ),
                      selected: filter == key,
                      onSelected: (_) => setState(() => filter = key),
                    ),
                ],
              ),
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
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 6,
                        ),
                        title: Text(
                          '${row['title'] ?? 'Kitob'}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          [
                            if ('${row['author'] ?? ''}'.trim().isNotEmpty)
                              'Muallif: ${row['author']}',
                            if ('${row['phone'] ?? ''}'.trim().isNotEmpty)
                              'Telefon: ${row['phone']}',
                            'Holat: ${statusLabels[status] ?? status}',
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          enabled: id != null && !saving.contains(id),
                          tooltip: 'So‘rov holatini o‘zgartirish',
                          icon: saving.contains(id)
                              ? const Icon(Icons.hourglass_top_rounded)
                              : const Icon(Icons.more_vert_rounded),
                          onSelected: (next) => _update(row, next),
                          itemBuilder: (_) => statusLabels.entries
                              .map(
                                (e) => PopupMenuItem<String>(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
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
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Kitoblar va ombor')),
              body: _BooksAdmin(api: widget.api, initialFilter: filter),
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() => future = _load());
        });
  }

  void _openTracking() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Yangi ilova zakazlari — tracking yo‘q'),
              ),
              body: _OrdersAdmin(
                api: widget.api,
                initialFilter: 'tracking_missing',
              ),
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() => future = _load());
        });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(
      title: const Text('Nazorat markazi'),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => setState(() => future = _load()),
        ),
      ],
    ),
    body: FutureBuilder<({List<Book> books, List<ShopOrder> orders})>(
      future: future,
      builder: (ctx, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Text('Nazorat markazi yuklanmadi: ${snapshot.error}'),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final books = snapshot.data!.books.where((b) => b.isActive).toList();
        final orders = snapshot.data!.orders;
        final noPages = books.where((b) => b.pageCount <= 0).length;
        final noAuthor = books
            .where(
              (b) =>
                  b.author.trim().isEmpty ||
                  b.author.trim() == 'Ko‘rsatilmagan',
            )
            .length;
        final noPublisher = books
            .where((b) => b.publisher.trim().isEmpty)
            .length;
        final lowStock = books.where((b) => b.stock > 0 && b.stock <= 2).length;
        final noDescription = books
            .where((b) => b.description.trim().isEmpty)
            .length;
        final tracking = orders.where(_requiresAppShipmentTracking).length;
        final items = <(String, String, int, IconData, VoidCallback)>[
          (
            'Sahifa soni yetishmaydi',
            'Kitoblar ma’lumotini to‘ldirish',
            noPages,
            Icons.menu_book_outlined,
            () => _openBookFilter('missing_page_count'),
          ),
          (
            'Nashriyoti yo‘q',
            'Nashriyot nomlarini to‘ldirish',
            noPublisher,
            Icons.business_outlined,
            () => _openBookFilter('missing_publisher'),
          ),
          (
            'Muallifi yo‘q',
            'Mualliflarni to‘ldirish',
            noAuthor,
            Icons.person_outline,
            () => _openBookFilter('missing_author'),
          ),
          (
            'Tavsifi yo‘q',
            'Kitob tavsiflarini to‘ldirish',
            noDescription,
            Icons.notes_outlined,
            () => _openBookFilter('missing_description'),
          ),
          (
            'Kam qolgan kitoblar',
            '1 yoki 2 dona qolganlar',
            lowStock,
            Icons.inventory_2_outlined,
            () => _openBookFilter('low_stock'),
          ),
          (
            'Tracking kiritilmagan',
            'Faqat yangi ilova zakazlari; eski, Telegram va Instagram chiqarilgan',
            tracking,
            Icons.local_shipping_outlined,
            _openTracking,
          ),
        ];
        return RefreshIndicator(
          onRefresh: () async {
            final data = await _load();
            if (mounted) setState(() => future = Future.value(data));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            children: [
              const Text(
                'Tuzatilishi kerak bo‘lgan ma’lumotlar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Raqamlar joriy ombor va buyurtmalar ro‘yxatidan '
                'hisoblanadi. Hech narsa avtomatik o‘chirilmaydi.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 15),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      leading: Icon(item.$4, color: AppColors.navy),
                      title: Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(item.$2),
                      trailing: Text(
                        '${item.$3} ta',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onTap: item.$5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text('Mijozlar so‘ragan kitoblarni boshqarish'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _RequestedBooksAdminPage(api: widget.api),
                  ),
                ),
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
    final todayRevenue = ((await widget.api._rpc(
      'admin_release_today_revenue',
      params: {'p_secret': widget.api.secret},
    )) as num).toInt();
    final newOrders = orders.where((order) => order.status == 'new').length;
    final acceptedOrders = orders.where(_adminAwaitingPreparation).length;
    final preparedOrders = orders.where(_adminPreparedForDispatch).length;
    final soldOutCount = books
        .where((book) => book.isActive && book.stock == 0)
        .length;

    // The metric is shown only when every relevant source answers. A failed
    // endpoint must not silently be counted as zero customer orders.
    int? preorderCount;
    try {
      final insight = await widget.api.merchandisingInsights().timeout(
        const Duration(seconds: 4),
      );
      final nativeRows = insight['preorders'] as List?;
      if (nativeRows != null) {
        if (webPreordersAvailable) {
          final webRows = await WebPreorderApi()
              .admin(widget.api.secret, 'list')
              .timeout(const Duration(seconds: 4));
          if (webRows is List)
            preorderCount = nativeRows.length + webRows.length;
        } else {
          preorderCount = nativeRows.length;
        }
      }
    } catch (_) {
      preorderCount = null;
    }
    return _AdminHomeData(
      books: books,
      orders: orders,
      todayRevenue: todayRevenue,
      newOrders: newOrders,
      acceptedOrders: acceptedOrders,
      preparedOrders: preparedOrders,
      soldOutCount: soldOutCount,
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: _OrdersAdmin(api: widget.api, initialFilter: filter),
        ),
      ),
    );
    if (mounted) unawaited(reloadQuietly());
  }

  Future<void> _openPreorderMetric() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CombinedPreorderPage(api: widget.api),
      ),
    );
    if (mounted) unawaited(reloadQuietly());
  }

  Future<void> _openSoldoutMetric(List<Book> books) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AdminBookListPage(
          title: 'Tugagan kitoblar',
          books: books.where((b) => b.isActive && b.stock == 0).toList(),
        ),
      ),
    );
    if (mounted) unawaited(reloadQuietly());
  }

  Future<void> _openSoldoutBooks(BuildContext sectionContext) async {
    try {
      final books = await widget.api.books();
      if (!sectionContext.mounted) return;
      _pushPage(
        sectionContext,
        _AdminBookListPage(
          title: 'Tugagan kitoblar',
          books: books.where((b) => b.isActive && b.stock == 0).toList(),
        ),
      );
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
      _pushPage(
        sectionContext,
        WebAdminToolsPage(secret: widget.api.secret, books: books),
      );
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
      _AdminMenuAction(
        'Pochta zakaslari',
        'Manzil, jo‘natmalar va tracking',
        Icons.local_shipping_outlined,
        (ctx) => _pushPage(
          ctx,
          Scaffold(
            appBar: AppBar(title: const Text('Pochta zakaslari')),
            body: _ShippingQueueAdmin(api: widget.api),
          ),
        ),
      ),
      _AdminMenuAction(
        'Kitoblar foydasi',
        'Sotilgan paytdagi tan narx va o‘zgarmas foyda tarixi',
        Icons.bar_chart_rounded,
        (ctx) => _pushPage(ctx, AdminBookProfitPage(secret: widget.api.secret)),
      ),
      _AdminMenuAction(
        'Ombor va qoldiqlar',
        'Kirgan va sotilgan kitoblar qoldig‘i',
        Icons.inventory_2_outlined,
        (ctx) => _goToTab(ctx, 2),
      ),
      _AdminMenuAction(
        'Tugagan kitoblar',
        'Omborda 0 dona qolgan kitoblar',
        Icons.inventory_2_outlined,
        (ctx) => unawaited(_openSoldoutBooks(ctx)),
      ),
      _AdminMenuAction(
        'Katalog tartibi',
        'Mijozlar ko‘radigan kitoblarni tartiblash',
        Icons.vertical_align_top_rounded,
        (ctx) => _pushPage(ctx, _CatalogPinsAdminPage(api: widget.api)),
      ),
      if (_enhancedAdminUi)
        _AdminMenuAction(
          'Biznes asboblari',
          'Tan narx, partiyalar va taqqoslash',
          Icons.calculate_outlined,
          (ctx) => unawaited(_openBusinessTools(ctx)),
        ),
      _AdminMenuAction(
        'Oldindan zakaslar',
        'Qabul, avans, qolgan to‘lov va jo‘natish',
        Icons.event_available_outlined,
        (ctx) => _pushPage(ctx, _CombinedPreorderPage(api: widget.api)),
      ),
      if (webPreordersAvailable)
        _AdminMenuAction(
          'Oldindan buyurtma sozlamalari',
          'Mijoz so‘rovlari va oldindan buyurtma qabuli',
          Icons.fact_check_outlined,
          (ctx) =>
              _pushPage(ctx, WebPreorderAdminPage(secret: widget.api.secret)),
        ),
      _AdminMenuAction(
        'Batafsil statistika',
        'Qo‘shimcha hisobot va ko‘rsatkichlar',
        Icons.insights_outlined,
        (ctx) => _pushPage(
          ctx,
          Scaffold(
            appBar: AppBar(title: const Text('Batafsil statistika')),
            body: _OverviewAdmin(
              api: widget.api,
              onOpenTab: (tab) {
                Navigator.of(ctx).pop();
                Navigator.of(ctx).pop();
                widget.onOpenTab(tab);
              },
            ),
          ),
        ),
      ),
      _AdminMenuAction(
        'Profil tiklash va sharhlar',
        'PIN tiklash so‘rovlari va sharh shikoyatlari',
        Icons.admin_panel_settings_outlined,
        (ctx) => _pushPage(ctx, _CustomerSafetyAdmin(api: widget.api)),
      ),
      _AdminMenuAction(
        'Mijozlar',
        'Ro‘yxat va mijozlar statistikasi',
        Icons.people_alt_outlined,
        (ctx) => _goToTab(ctx, 5),
      ),
      _AdminMenuAction(
        'Savdo imkoniyatlari',
        'Chegirmalar, kutayotganlar va xabar yuborish',
        Icons.campaign_outlined,
        (ctx) => _pushPage(ctx, _MerchandisingAdminPage(api: widget.api)),
      ),
      _AdminMenuAction(
        'Muhim e’lon',
        'Mijozlarga ko‘rinadigan do‘kon e’loni',
        Icons.notifications_active_outlined,
        (ctx) => _pushPage(ctx, _EmergencyNoticeAdmin(api: widget.api)),
      ),
      _AdminMenuAction(
        'Admin AI',
        'Kitob va biznes bo‘yicha AI vositalar',
        Icons.auto_awesome_outlined,
        (ctx) => _goToTab(ctx, 7),
      ),
      _AdminMenuAction(
        'Admin bildirishnomalari',
        'Yangi buyurtmalar uchun push xabarlari',
        Icons.notifications_outlined,
        (_) => widget.onPushSettings(),
      ),
    ];
    _pushPage(
      context,
      _AdminSectionPage(
        title: 'Qo‘shimcha bo‘limlar',
        subtitle:
            'Asosiy oltita sahifa faqat pastki menyuda. '
            'Bu yerda esa qolgan kerakli boshqaruv vositalari jamlangan.',
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AdminHomeData>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 12),
                  const Text('Boshqaruv ma’lumotlari yuklanmadi.'),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Qayta urinish'),
                  ),
                ],
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      return RefreshIndicator(
        onRefresh: reloadQuietly,
        child: Center(
          child: ConstrainedBox(
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
                  child: Row(
                    children: [
                      const MuhajeerLogoBadge(
                        size: 46,
                        radius: 12,
                        showShadow: false,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MUHAJEER BOOKS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Boshqaruv paneli',
                              style: TextStyle(color: Color(0xFFE7F3F1)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: reload,
                        tooltip: 'Yangilash',
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: widget.onPushSettings,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Admin pushni yoqish'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pushPage(
                        context,
                        Scaffold(
                          appBar: AppBar(title: const Text('Xabarnoma yuborish')),
                          body: _PushNotificationAdmin(api: widget.api),
                        ),
                      ),
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Mijozlarga xabar yuborish'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Bugungi holat',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (ctx, size) {
                    final columns = size.maxWidth >= 720 ? 4 : 2;
                    final gap = 10.0;
                    final width =
                        (size.maxWidth - gap * (columns - 1)) / columns;
                    // Card order follows the operational workflow. Every count
                    // opens its own relevant and pre-filtered list.
                    final metrics = <(String, String, IconData, VoidCallback)>[
                      (
                        'Bugungi savdo',
                        _won(data.todayRevenue),
                        Icons.payments_outlined,
                        () => unawaited(
                          _openOrderMetric(
                            'Bugungi kitob savdosi',
                            'today_sales',
                          ),
                        ),
                      ),
                      (
                        'Yangi buyurtmalar',
                        '${data.newOrders} ta',
                        Icons.shopping_cart_outlined,
                        () => unawaited(
                          _openOrderMetric('Yangi buyurtmalar', 'new'),
                        ),
                      ),
                      (
                        'Qabul qilingan',
                        '${data.acceptedOrders} ta',
                        Icons.fact_check_outlined,
                        () => unawaited(
                          _openOrderMetric(
                            'Qabul qilingan buyurtmalar',
                            'accepted',
                          ),
                        ),
                      ),
                      (
                        'Jo‘natishga tayyor',
                        '${data.preparedOrders} ta',
                        Icons.inventory_outlined,
                        () => unawaited(
                          _openOrderMetric('Jo‘natishga tayyor', 'prepared'),
                        ),
                      ),
                      (
                        'Tugagan kitoblar',
                        '${data.soldOutCount} ta',
                        Icons.inventory_2_outlined,
                        () => unawaited(_openSoldoutMetric(data.books)),
                      ),
                      (
                        'Oldindan zakazlar',
                        data.preorderCount == null
                            ? '—'
                            : '${data.preorderCount} ta',
                        Icons.event_available_outlined,
                        () => unawaited(_openPreorderMetric()),
                      ),
                    ];
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
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
                                  constraints: const BoxConstraints(
                                    minHeight: 114,
                                  ),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Icon(
                                            metrics[i].$3,
                                            size: 21,
                                            color: AppColors.success,
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 17,
                                            color: AppColors.muted,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        metrics[i].$1,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        metrics[i].$2,
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
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        color: AppColors.muted,
                        size: 19,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Qo‘shimcha boshqaruv uchun pastdagi “Bo‘limlar”ni bosing.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
