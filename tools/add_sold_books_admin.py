from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"Missing patch anchor: {label}")
    return text.replace(old, new, 1)

path = Path('lib/admin_ui.dart')
text = path.read_text(encoding='utf-8')

# Admin API: shared sold-book history from Supabase.
anchor = '''  Future<String> paymentProofUrl(String path) async {'''
insert = '''  Future<List<Map<String, dynamic>>> sales() async {
    final raw = await client.rpc(
      'admin_list_sales',
      params: {'p_secret': secret, 'p_limit': 5000},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

'''
text = replace_once(text, anchor, insert + anchor, 'sales api')

text = replace_once(
    text,
    '''  final _ordersKey = GlobalKey<_OrdersAdminState>();
  final _customersKey = GlobalKey<_CustomersAdminState>();''',
    '''  final _ordersKey = GlobalKey<_OrdersAdminState>();
  final _salesKey = GlobalKey<_SalesAdminState>();
  final _customersKey = GlobalKey<_CustomersAdminState>();''',
    'sales key',
)

text = replace_once(
    text,
    '''    'Buyurtmalar',
    'Mijozlar',
    'Chegirmalar',''',
    '''    'Buyurtmalar',
    'Sotilgan kitoblar',
    'Mijozlar',
    'Chegirmalar',''',
    'titles',
)

text = replace_once(
    text,
    '''    Icons.receipt_long_rounded,
    Icons.people_alt_rounded,
    Icons.percent_rounded,''',
    '''    Icons.receipt_long_rounded,
    Icons.sell_rounded,
    Icons.people_alt_rounded,
    Icons.percent_rounded,''',
    'icons',
)

text = replace_once(
    text,
    '''        case 3:
          unawaited(_ordersKey.currentState?.reloadQuietly());
        case 4:
          unawaited(_customersKey.currentState?.reloadQuietly());''',
    '''        case 3:
          unawaited(_ordersKey.currentState?.reloadQuietly());
        case 4:
          unawaited(_salesKey.currentState?.reloadQuietly());
        case 5:
          unawaited(_customersKey.currentState?.reloadQuietly());''',
    'refresh timer',
)

text = replace_once(
    text,
    '''      _OrdersAdmin(key: _ordersKey, api: api),
      _CustomersAdmin(key: _customersKey, api: api),
      _DiscountAdmin(api: api),''',
    '''      _OrdersAdmin(key: _ordersKey, api: api),
      _SalesAdmin(key: _salesKey, api: api),
      _CustomersAdmin(key: _customersKey, api: api),
      _DiscountAdmin(api: api),''',
    'pages',
)

rail_anchor = '''      NavigationRailDestination(
        icon: Icon(Icons.people_alt_outlined),
        selectedIcon: Icon(Icons.people_alt_rounded),
        label: Text('Mijozlar'),
      ),'''
rail_insert = '''      NavigationRailDestination(
        icon: Icon(Icons.sell_outlined),
        selectedIcon: Icon(Icons.sell_rounded),
        label: Text('Sotilgan kitoblar'),
      ),
'''
text = replace_once(text, rail_anchor, rail_insert + rail_anchor, 'rail destination')

sales_page = r'''class _SalesAdmin extends StatefulWidget {
  const _SalesAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_SalesAdmin> createState() => _SalesAdminState();
}

class _SalesAdminState extends State<_SalesAdmin> {
  late Future<List<Map<String, dynamic>>> future;
  String query = '';
  String source = 'all';

  @override
  void initState() {
    super.initState();
    future = widget.api.sales();
  }

  void reload() {
    if (!mounted) return;
    setState(() => future = widget.api.sales());
  }

  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.sales();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // 5 soniyalik fon yangilanishida eski ro‘yxat ekranda qoladi.
    }
  }

  String _sourceLabel(String value) {
    switch (value) {
      case 'instagram':
        return 'Instagram';
      case 'telegram':
        return 'Telegram';
      default:
        return 'Ilova';
    }
  }

  IconData _sourceIcon(String value) {
    switch (value) {
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'telegram':
        return Icons.send_outlined;
      default:
        return Icons.phone_iphone_rounded;
    }
  }

  DateTime? _soldAt(Map<String, dynamic> row) {
    final raw = (row['sold_at'] ?? '').toString();
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: AppSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.danger),
                  const SizedBox(height: 10),
                  const Text('Sotuv tarixini yuklab bo‘lmadi',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Qayta urinish'),
                  ),
                ],
              ),
            ),
          );
        }

        final all = snap.data ?? const <Map<String, dynamic>>[];
        final now = DateTime.now();
        final todayCount = all.where((row) {
          final dt = _soldAt(row);
          return dt != null &&
              dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day;
        }).length;
        final monthCount = all.where((row) {
          final dt = _soldAt(row);
          return dt != null && dt.year == now.year && dt.month == now.month;
        }).length;

        final q = query.trim().toLowerCase();
        final filtered = all.where((row) {
          final rowSource = (row['source'] ?? 'app').toString();
          final title = (row['title'] ?? 'Kitob').toString();
          final matchesSource = source == 'all' || rowSource == source;
          final matchesQuery = q.isEmpty || title.toLowerCase().contains(q);
          return matchesSource && matchesQuery;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeading(
                    title: 'Sotilgan kitoblar',
                    subtitle:
                        'Ilova, Telegram va Instagram savdolari bitta tarixda saqlanadi.',
                    trailing: IconButton.filledTonal(
                      onPressed: reload,
                      tooltip: 'Yangilash',
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      AppInfoPill(
                        icon: Icons.auto_stories_rounded,
                        label: 'Jami ${all.length} ta',
                        foreground: AppColors.navy,
                        background: AppColors.infoSoft,
                        border: AppColors.border,
                      ),
                      AppInfoPill(
                        icon: Icons.today_rounded,
                        label: 'Bugun $todayCount ta',
                        foreground: AppColors.success,
                        background: AppColors.successSoft,
                        border: AppColors.border,
                      ),
                      AppInfoPill(
                        icon: Icons.calendar_month_rounded,
                        label: 'Shu oy $monthCount ta',
                        foreground: AppColors.orange,
                        background: const Color(0xFFFFF3E3),
                        border: AppColors.border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Kitob nomi bo‘yicha qidirish...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in const [
                          ('all', 'Barchasi'),
                          ('app', 'Ilova'),
                          ('telegram', 'Telegram'),
                          ('instagram', 'Instagram'),
                        ]) ...[
                          ChoiceChip(
                            label: Text(item.$2),
                            selected: source == item.$1,
                            onSelected: (_) => setState(() => source = item.$1),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => reload(),
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Hozircha mos sotuv topilmadi.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = filtered[index];
                          final title = (row['title'] ?? 'Kitob').toString();
                          final rowSource = (row['source'] ?? 'app').toString();
                          final dt = _soldAt(row);
                          final date = dt == null
                              ? '—'
                              : DateFormat('dd.MM.yyyy').format(dt);
                          return AppSurface(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    '${index + 1}.',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '$title ($date)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: _sourceLabel(rowSource),
                                  child: Icon(
                                    _sourceIcon(rowSource),
                                    size: 19,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

'''
text = replace_once(
    text,
    'class _CustomersAdmin extends StatefulWidget {',
    sales_page + 'class _CustomersAdmin extends StatefulWidget {',
    'sales page',
)

path.write_text(text, encoding='utf-8')
print('Added sold-books admin page')
