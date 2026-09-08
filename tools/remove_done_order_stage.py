from pathlib import Path

p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')

replacements = [
    ("""          final completedRevenue = orders
              .where((o) => o.status == 'done')
              .fold<int>(0, (sum, o) => sum + o.total);""",
     """          final completedRevenue = orders
              .where((o) => o.status == 'shipping')
              .fold<int>(0, (sum, o) => sum + o.total);"""),
    ("['accepted', 'paid', 'shipping', 'done'].contains(o.status)", "['accepted', 'paid', 'shipping'].contains(o.status)"),
    ("final activeStatuses = {'accepted', 'paid', 'shipping', 'done'};", "final activeStatuses = {'accepted', 'paid', 'shipping'};"),
    ("          final doneOrders = orders.where((o) => o.status == 'done').length;\n", ""),
    ("              orders.isEmpty ? 0 : ((doneOrders / orders.length) * 100).round();", "              orders.isEmpty ? 0 : ((shippingOrders / orders.length) * 100).round();"),
    ("label: 'Yakunlangan savdo',", "label: 'Jo‘natilgan savdo',"),
    ("note: 'Yakunlangan buyurtmalar',", "note: 'Jo‘natilgan buyurtmalar',"),
    ("""                          AppInfoPill(
                            icon: Icons.task_alt_rounded,
                            label: '$doneOrders yakunlangan',
                            foreground: AppColors.navy,
                            background: AppColors.surfaceSoft,
                          ),
""", ""),
    ("label: 'Yakunlangan buyurtmalar',", "label: 'Jo‘natilgan buyurtmalar',"),
    ("""                        _OrderFilterChip(
                          label: 'Yakunlangan',
                          value: 'done',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
""", ""),
    ("""    } else if (order.status == 'shipping') {
      primaryStatus = 'done';
      primaryLabel = 'Yakunlash';
      primaryIcon = Icons.task_alt_rounded;
    }
""", "    }\n"),
    ("""      'shipping' => (
          'Jo‘natildi',
          AppColors.orange,
          const Color(0xFFFFF2E3),
          const Color(0xFFFFD4A3),
          Icons.local_shipping_rounded,
        ),
      'done' => (
          'Yakunlandi',
          AppColors.success,
          AppColors.successSoft,
          const Color(0xFFCDEAD7),
          Icons.task_alt_rounded,
        ),
""", """      'shipping' => (
          'Jo‘natildi',
          AppColors.success,
          AppColors.successSoft,
          const Color(0xFFCDEAD7),
          Icons.local_shipping_rounded,
        ),
      // Eski buildlardan qolgan 'done' yozuvi uchrasa ham alohida
      // bosqich ko‘rsatmaymiz: Jo‘natildi yakuniy holat.
      'done' => (
          'Jo‘natildi',
          AppColors.success,
          AppColors.successSoft,
          const Color(0xFFCDEAD7),
          Icons.local_shipping_rounded,
        ),
"""),
    ("'Ochiq buyurtmalar: ${stats['open_orders'] ?? 0} • Yakunlangan: ${stats['completed_orders'] ?? 0}'", "'Ochiq buyurtmalar: ${stats['open_orders'] ?? 0} • Jo‘natilgan: ${stats['completed_orders'] ?? 0}'"),
]

missing = []
for old, new in replacements:
    if old not in s:
        missing.append(old[:100].replace('\n', ' '))
    else:
        s = s.replace(old, new)

if missing:
    raise SystemExit('Missing patterns: ' + ' | '.join(missing))

p.write_text(s, encoding='utf-8')
print('Removed Yakunlandi stage; Jo‘natildi is final and green.')
