from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


p = Path("lib/admin_ui.dart")
s = p.read_text(encoding="utf-8")

# Admin API helper.
customers_anchor = """  Future<List<Map<String, dynamic>>> customers() async {
    final raw = await client.rpc(
      'admin_list_customers',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

class AdminGatePage"""
customers_new = """  Future<List<Map<String, dynamic>>> customers() async {
    final raw = await client.rpc(
      'admin_list_customers',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> restockWaitlist() async {
    final raw = await client.rpc(
      'admin_restock_waitlist',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

class AdminGatePage"""
if "restockWaitlist()" not in s:
    s = replace_once(s, customers_anchor, customers_new, "admin restock API")

# Dashboard navigation/key.
if "_restockKey" not in s:
    s = replace_once(
        s,
        "  final _customersKey = GlobalKey<_CustomersAdminState>();\n",
        "  final _customersKey = GlobalKey<_CustomersAdminState>();\n  final _restockKey = GlobalKey<_RestockAdminState>();\n",
        "restock dashboard key",
    )

if "    'Kutayotganlar',\n" not in s:
    s = replace_once(
        s,
        "    'Mijozlar',\n    'Chegirmalar',\n",
        "    'Mijozlar',\n    'Kutayotganlar',\n    'Chegirmalar',\n",
        "restock dashboard title",
    )

if "    Icons.notifications_active_rounded,\n    Icons.percent_rounded,\n" not in s:
    s = replace_once(
        s,
        "    Icons.people_alt_rounded,\n    Icons.percent_rounded,\n",
        "    Icons.people_alt_rounded,\n    Icons.notifications_active_rounded,\n    Icons.percent_rounded,\n",
        "restock dashboard icon",
    )

if "_restockKey.currentState?.reloadQuietly" not in s:
    s = replace_once(
        s,
        "        case 5:\n          unawaited(_customersKey.currentState?.reloadQuietly());\n      }\n",
        "        case 5:\n          unawaited(_customersKey.currentState?.reloadQuietly());\n        case 6:\n          unawaited(_restockKey.currentState?.reloadQuietly());\n      }\n",
        "restock live refresh",
    )

if "_RestockAdmin(key: _restockKey" not in s:
    s = replace_once(
        s,
        "      _CustomersAdmin(key: _customersKey, api: api),\n      _DiscountAdmin(api: api),\n",
        "      _CustomersAdmin(key: _customersKey, api: api),\n      _RestockAdmin(key: _restockKey, api: api),\n      _DiscountAdmin(api: api),\n",
        "restock page",
    )

if "label: Text('Kutayotganlar')" not in s:
    s = replace_once(
        s,
        "      NavigationRailDestination(\n        icon: Icon(Icons.percent_rounded),\n        label: Text('Chegirma'),\n      ),\n",
        "      NavigationRailDestination(\n        icon: Icon(Icons.notifications_none_rounded),\n        selectedIcon: Icon(Icons.notifications_active_rounded),\n        label: Text('Kutayotganlar'),\n      ),\n      NavigationRailDestination(\n        icon: Icon(Icons.percent_rounded),\n        label: Text('Chegirma'),\n      ),\n",
        "restock rail destination",
    )

# Restock waitlist admin page.
restock_page = r'''class _RestockAdmin extends StatefulWidget {
  const _RestockAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_RestockAdmin> createState() => _RestockAdminState();
}

class _RestockAdminState extends State<_RestockAdmin> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.restockWaitlist();
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _when(dynamic value) {
    final dt = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  void reload() {
    if (!mounted) return;
    setState(() => future = widget.api.restockWaitlist());
  }

  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.restockWaitlist();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Fon yangilanishi eski ma'lumotni ekranda qoldiradi.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: AppSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_off_outlined,
                    size: 42,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kutayotganlar ro‘yxatini yuklab bo‘lmadi',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
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

        final rows = snap.data ?? const <Map<String, dynamic>>[];
        final totalWaiting = rows.fold<int>(
          0,
          (sum, row) => sum + _asInt(row['waiting_count']),
        );

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const AppPageHeading(
              title: 'Sotuvga qaytishini kutayotganlar',
              subtitle:
                  'Mavjud bo‘lmagan qaysi kitobni nechta mijoz kutayotganini shu yerda ko‘rasiz.',
            ),
            const SizedBox(height: 16),
            AppSurface(
              backgroundColor: AppColors.surfaceSoft,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalWaiting ta kutish so‘rovi',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${rows.length} ta kitob bo‘yicha',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yangilash',
                    onPressed: reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              AppSurface(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Hozircha kutayotgan mijoz yo‘q',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mijoz “Kelganda xabar berish”ni bossa, shu yerda chiqadi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...rows.map((row) {
                final count = _asInt(row['waiting_count']);
                final stock = _asInt(row['stock']);
                final lastRequest = _when(row['last_requested_at']);
                final title = (row['title'] ?? 'Nomsiz kitob').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppSurface(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E6),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: _orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                stock <= 0
                                    ? 'Hozir sotuvda mavjud emas'
                                    : 'Omborda: $stock ta',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (lastRequest.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Oxirgi so‘rov: $lastRequest',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFFFD6A3),
                            ),
                          ),
                          child: Text(
                            '$count kishi kutyapti',
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

'''

if "class _RestockAdmin extends StatefulWidget" not in s:
    s = replace_once(
        s,
        "class _DiscountAdmin extends StatefulWidget {",
        restock_page + "class _DiscountAdmin extends StatefulWidget {",
        "restock admin page",
    )

p.write_text(s, encoding="utf-8")
print("Admin restock waitlist patch applied")
